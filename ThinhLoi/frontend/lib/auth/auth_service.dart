import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EmployeeAuthStatus {
  initializing,
  signedOut,
  authenticating,
  checking,
  signedIn,
  unauthorized,
  failure,
}

String normalizeVietnamesePhone(String value) {
  var digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+84')) return digits;
  digits = digits.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('84')) return '+$digits';
  if (digits.startsWith('0')) return '+84${digits.substring(1)}';
  return value.trim();
}

bool isVietnamesePhone(String value) =>
    RegExp(r'^\+84[0-9]{9,10}$').hasMatch(normalizeVietnamesePhone(value));

bool isUsername(String value) =>
    RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(value.trim().toLowerCase());

class AuthService {
  AuthService(this.client);
  final SupabaseClient client;
  Future<void> saveLinkOwner(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove('packflow.googleLinkOwner');
      await prefs.remove('packflow.googleLinkTime');
    } else {
      await prefs.setString('packflow.googleLinkOwner', id);
      await prefs.setInt(
        'packflow.googleLinkTime',
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  Future<String?> pendingLinkOwner() async {
    final prefs = await SharedPreferences.getInstance();
    final started = prefs.getInt('packflow.googleLinkTime') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - started > 600000) {
      await saveLinkOwner(null);
      return null;
    }
    return prefs.getString('packflow.googleLinkOwner');
  }

  String? get userId => client.auth.currentUser?.id;
  bool get isGoogleSession =>
      client.auth.currentUser?.appMetadata['provider'] == 'google';
  Stream<AuthState> get changes => client.auth.onAuthStateChange;
  Future<void> logout() => client.auth.signOut(scope: SignOutScope.local);
  Future<bool> hasGoogleIdentity() async {
    final user = (await client.auth.getUser()).user;
    return user?.identities?.any((identity) => identity.provider == 'google') ??
        false;
  }

  String get redirect =>
      kIsWeb ? '${Uri.base.origin}/' : 'vn.packflow.app://login-callback/';

  Future<void> signIn(String identifier, String password) async {
    final normalized = identifier.trim().toLowerCase();
    if (isVietnamesePhone(identifier)) {
      await client.auth.signInWithPassword(
        phone: normalizeVietnamesePhone(identifier),
        password: password,
      );
      return;
    }
    if (!isUsername(normalized)) {
      throw const FormatException('Tên đăng nhập không hợp lệ.');
    }
    final response = await client.functions.invoke(
      'login-with-username',
      body: {'username': normalized, 'password': password},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final refreshToken = data['refresh_token'] as String?;
    if (refreshToken == null) {
      throw const AuthException('Invalid login credentials');
    }
    await client.auth.setSession(refreshToken);
  }

  Future<bool> signInWithGoogle() => client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: redirect,
    scopes: 'openid email profile',
    authScreenLaunchMode: kIsWeb
        ? LaunchMode.platformDefault
        : LaunchMode.externalApplication,
    queryParams: const {'prompt': 'select_account'},
  );

  Future<bool> linkGoogle() => client.auth.linkIdentity(
    OAuthProvider.google,
    redirectTo: redirect,
    scopes: 'openid email profile',
    authScreenLaunchMode: kIsWeb
        ? LaunchMode.platformDefault
        : LaunchMode.externalApplication,
  );

  Future<Map<String, dynamic>?> profile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<void> sendRecovery(String email) => client.auth.resetPasswordForEmail(
    email.trim(),
    redirectTo: kIsWeb ? Uri.base.origin : 'vn.packflow.app://login-callback/',
  );
}

class AuthController extends ChangeNotifier {
  AuthController(this.service, {this.clearData, this.onAuthorized});
  final AuthService service;
  final VoidCallback? clearData;
  final Future<void> Function()? onAuthorized;
  StreamSubscription<AuthState>? _subscription;
  Timer? _poll;
  Timer? _oauthTimeout;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _validation;
  String? _validatingUser;
  String? _authorizedUser;
  String? _linkingUser;
  bool oauthPending = false;
  bool googleLinked = false;
  bool get busy => oauthPending || status == EmployeeAuthStatus.authenticating;
  EmployeeAuthStatus status = EmployeeAuthStatus.initializing;
  String? message;
  Map<String, dynamic>? employee;

  Future<void> initialize() async {
    _linkingUser ??= await service.pendingLinkOwner();
    if (_disposed) return;
    _subscription ??= service.changes.listen(
      (event) {
        if (event.event == AuthChangeEvent.signedOut) {
          _reset();
          _emit();
        } else {
          unawaited(recheck());
        }
      },
      onError: (Object error) {
        oauthPending = false;
        _oauthTimeout?.cancel();
        message = authErrorMessage(error);
        if (service.userId == null) status = EmployeeAuthStatus.signedOut;
        _emit();
      },
    );
    _poll ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (service.userId != null && !busy) unawaited(recheck());
    });
    await recheck();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _reset({bool preserveLink = false}) {
    _generation++;
    _authorizedUser = null;
    _validation = null;
    _validatingUser = null;
    if (!preserveLink) {
      _linkingUser = null;
      unawaited(service.saveLinkOwner(null));
    }
    employee = null;
    googleLinked = false;
    oauthPending = false;
    _oauthTimeout?.cancel();
    clearData?.call();
    status = EmployeeAuthStatus.signedOut;
  }

  Future<void> recheck() {
    final id = service.userId;
    if (id == null) {
      _reset(preserveLink: true);
      _emit();
      return Future.value();
    }
    if (_validation != null && _validatingUser == id) return _validation!;
    _validatingUser = id;
    final generation = ++_generation;
    final work = _validateSession(id, generation);
    _validation = work;
    return work.whenComplete(() {
      if (generation == _generation) {
        _validation = null;
        _validatingUser = null;
      }
    });
  }

  Future<void> _validateSession(String id, int generation) async {
    if (_authorizedUser != id) {
      clearData?.call();
      employee = null;
      status = EmployeeAuthStatus.checking;
      _emit();
    }
    try {
      final profile = await service.profile();
      if (_disposed || generation != _generation || service.userId != id) {
        return;
      }
      if (_linkingUser != null && _linkingUser != id) {
        await signOut();
        message = 'Tài khoản Google không khớp với nhân viên đang liên kết. Vui lòng đăng nhập lại.';
        _emit();
        return;
      }
      const roles = {'admin', 'warehouse_staff', 'sales_staff', 'accountant'};
      final allowed =
          profile?['id'] == id &&
          profile?['is_active'] == true &&
          roles.contains(profile?['role']);
      if (!allowed) {
        clearData?.call();
        _authorizedUser = null;
        employee = null;
        status = EmployeeAuthStatus.unauthorized;
      } else {
        final firstAccess = _authorizedUser != id;
        _authorizedUser = id;
        employee = profile;
        status = EmployeeAuthStatus.signedIn;
        if (firstAccess) unawaited(onAuthorized?.call() ?? Future.value());
      }
      oauthPending = false;
      _oauthTimeout?.cancel();
      _emit();
      if (allowed) {
        final linked = await service.hasGoogleIdentity();
        if (_disposed || generation != _generation || service.userId != id) {
          return;
        }
        googleLinked = linked;
        if (_linkingUser == id && linked) {
          message =
              'Đã liên kết tài khoản Google với hồ sơ nhân viên hiện tại.';
          _linkingUser = null;
          await service.saveLinkOwner(null);
        }
      }
    } catch (error) {
      if (_disposed || generation != _generation) return;
      clearData?.call();
      _authorizedUser = null;
      employee = null;
      message = authErrorMessage(error);
      status = EmployeeAuthStatus.failure;
    }
    _emit();
  }

  Future<bool> signIn(String identifier, String password) async {
    if (busy) return false;
    status = EmployeeAuthStatus.authenticating;
    message = null;
    notifyListeners();
    try {
      await service.signIn(identifier, password);
      await recheck();
      return status == EmployeeAuthStatus.signedIn;
    } catch (error) {
      message = authErrorMessage(error);
      status = EmployeeAuthStatus.signedOut;
      notifyListeners();
      return false;
    }
  }

  Future<void> google() async {
    if (busy) return;
    oauthPending = true;
    message = null;
    _emit();
    try {
      if (!await service.signInWithGoogle()) {
        cancelOAuth();
        return;
      }
      _oauthTimeout = Timer(const Duration(minutes: 3), cancelOAuth);
    } catch (error) {
      oauthPending = false;
      message = authErrorMessage(error);
      _emit();
    }
  }

  Future<void> linkGoogle() async {
    if (busy || status != EmployeeAuthStatus.signedIn) return;
    await recheck();
    if (status != EmployeeAuthStatus.signedIn || busy) return;
    _linkingUser = service.userId;
    oauthPending = true;
    message = null;
    _emit();
    try {
      await service.saveLinkOwner(_linkingUser);
      if (!await service.linkGoogle()) {
        cancelOAuth();
        return;
      }
      _oauthTimeout = Timer(const Duration(minutes: 3), cancelOAuth);
    } catch (error) {
      oauthPending = false;
      _linkingUser = null;
      await service.saveLinkOwner(null);
      message = authErrorMessage(error);
      _emit();
    }
  }

  void cancelOAuth() {
    oauthPending = false;
    _oauthTimeout?.cancel();
    _linkingUser = null;
    unawaited(service.saveLinkOwner(null));
    message = 'Chưa hoàn tất xác thực Google. Bạn có thể thử lại.';
    _emit();
  }

  Future<void> recover(String email) => service.sendRecovery(email);

  Future<void> signOut() async {
    try {
      await service.logout();
      _reset();
      message = null;
    } catch (error) {
      clearData?.call();
      employee = null;
      _authorizedUser = null;
      message = authErrorMessage(error);
      status = EmployeeAuthStatus.failure;
    }
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _poll?.cancel();
    _oauthTimeout?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

String authErrorMessage(Object error) {
  final code = error is AuthException ? error.code : null;
  return switch (code) {
    'identity_already_exists' || 'email_exists' => 'Tài khoản Google đã liên kết với người dùng khác. Vui lòng liên hệ quản trị viên.',
    'manual_linking_disabled' ||
    'provider_disabled' ||
    'oauth_provider_not_supported' => 'Đăng nhập hoặc liên kết Google chưa được cấu hình. Vui lòng liên hệ quản trị viên.',
    'access_denied' =>
      'Bạn đã hủy xác thực Google. Có thể thử lại khi sẵn sàng.',
    'bad_code_verifier' || 'flow_state_expired' || 'flow_state_not_found' => 'Liên kết đăng nhập đã hết hạn hoặc không hợp lệ. Vui lòng thử lại trên cùng trình duyệt.',
    'invalid_credentials' =>
      'Tên đăng nhập/số điện thoại hoặc mật khẩu không đúng.',
    'session_not_found' || 'refresh_token_not_found' =>
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    _ =>
      error is FunctionException || error is FormatException
          ? 'Không thể đăng nhập. Kiểm tra tên đăng nhập, mật khẩu hoặc thử lại sau.'
          : 'Không thể xác thực hoặc kiểm tra quyền lúc này. Kiểm tra kết nối và thử lại.',
  };
}
