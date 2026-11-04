import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:packflow/app.dart';
import 'package:packflow/auth/auth_service.dart';
import 'package:packflow/data/app_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuth extends AuthService {
  FakeAuth()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  String? id;
  Map<String, dynamic>? row;
  Object? failure;
  bool linked = false;
  String? linkOwner;
  int launches = 0;
  int links = 0;
  Completer<Map<String, dynamic>?>? query;
  final events = StreamController<AuthState>.broadcast();
  @override
  String? get userId => id;
  @override
  Stream<AuthState> get changes => events.stream;
  @override
  Future<String?> pendingLinkOwner() async => linkOwner;
  @override
  Future<void> saveLinkOwner(String? value) async {
    linkOwner = value;
  }

  @override
  Future<Map<String, dynamic>?> profile() async {
    if (failure != null) throw failure!;
    if (query != null) return query!.future;
    return row;
  }

  @override
  Future<bool> hasGoogleIdentity() async => linked;
  @override
  Future<bool> signInWithGoogle() async {
    launches++;
    if (failure != null) throw failure!;
    return true;
  }

  @override
  Future<bool> linkGoogle() async {
    links++;
    if (failure != null) throw failure!;
    return true;
  }

  @override
  Future<void> logout() async {
    id = null;
  }

  void employee({bool active = true, String? role = 'warehouse_staff'}) {
    id = 'employee-a';
    row = {'id': id, 'is_active': active, 'role': role};
  }
}

void main() {
  late FakeAuth api;
  late AuthController auth;
  int clears = 0;
  int loads = 0;
  bool controllerDisposed = false;
  setUp(() {
    controllerDisposed = false;
    api = FakeAuth();
    clears = 0;
    loads = 0;
    auth = AuthController(
      api,
      clearData: () => clears++,
      onAuthorized: () async {
        loads++;
      },
    );
  });
  tearDown(() async {
    if (!controllerDisposed) auth.dispose();
    await api.events.close();
    await api.client.dispose();
  });

  testWidgets('revocation removes protected routes and root dialogs', (
    tester,
  ) async {
    api.employee();
    await auth.initialize();
    final store = AppStore.seeded();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<AppStore>.value(value: store),
        ],
        child: const PackFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    final pageContext = tester.element(find.byType(AppShell));
    unawaited(
      showDialog<void>(
        context: pageContext,
        builder: (_) => const AlertDialog(content: Text('Dữ liệu nội bộ')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dữ liệu nội bộ'), findsOneWidget);
    api.employee(active: false);
    await auth.recheck();
    await tester.pumpAndSettle();
    expect(find.text('Dữ liệu nội bộ'), findsNothing);
    expect(find.byType(AppShell), findsNothing);
    expect(find.text('Không có quyền truy cập'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    auth.dispose();
    controllerDisposed = true;
  });

  test(
    'restores an approved employee and loads only once for duplicate checks',
    () async {
      api.employee();
      await auth.initialize();
      await Future.wait([auth.recheck(), auth.recheck()]);
      expect(auth.status, EmployeeAuthStatus.signedIn);
      expect(loads, 1);
    },
  );
  test('Google identity without profile is unauthorized', () async {
    api.id = 'unknown-google';
    await auth.initialize();
    expect(auth.status, EmployeeAuthStatus.unauthorized);
    expect(loads, 0);
  });
  for (final role in <String?>[null, 'owner', '']) {
    test('invalid role $role fails closed', () async {
      api.employee(role: role);
      await auth.initialize();
      expect(auth.status, EmployeeAuthStatus.unauthorized);
    });
  }
  test('disabled employee and mid-session revocation clear access', () async {
    api.employee();
    await auth.initialize();
    api.employee(active: false);
    await auth.recheck();
    expect(auth.status, EmployeeAuthStatus.unauthorized);
    expect(auth.employee, isNull);
    expect(clears, greaterThan(0));
  });
  test('database outage preserves session and allows retry', () async {
    api.employee();
    await auth.initialize();
    api.failure = Exception('offline');
    await auth.recheck();
    expect(auth.status, EmployeeAuthStatus.failure);
    expect(api.id, 'employee-a');
    api.failure = null;
    await auth.recheck();
    expect(auth.status, EmployeeAuthStatus.signedIn);
  });
  test('late profile response cannot restore access after logout', () async {
    api.employee();
    api.query = Completer();
    final pending = auth.recheck();
    await auth.signOut();
    api.query!.complete(api.row);
    await pending;
    expect(auth.status, EmployeeAuthStatus.signedOut);
    expect(auth.employee, isNull);
    expect(loads, 0);
  });
  test('duplicate Google taps launch once and cancel enables retry', () async {
    await auth.initialize();
    await Future.wait([auth.google(), auth.google()]);
    expect(api.launches, 1);
    expect(auth.status, EmployeeAuthStatus.signedOut);
    auth.cancelOAuth();
    await auth.google();
    expect(api.launches, 2);
  });
  test('provider error is Vietnamese without raw sensitive details', () async {
    api.failure = const AuthException(
      'secret detail',
      code: 'provider_disabled',
    );
    await auth.google();
    expect(auth.oauthPending, isFalse);
    expect(auth.message, contains('chưa được cấu hình'));
    expect(auth.message, isNot(contains('secret')));
  });
  test(
    'linking requires approved profile and preserves original user ID',
    () async {
      await auth.linkGoogle();
      expect(api.links, 0);
      api.employee();
      await auth.initialize();
      await auth.linkGoogle();
      expect(api.linkOwner, 'employee-a');
      api.linked = true;
      await auth.recheck();
      expect(auth.googleLinked, isTrue);
      expect(auth.employee?['id'], 'employee-a');
      expect(api.linkOwner, isNull);
    },
  );
  test('link callback with different identity fails closed', () async {
    api.employee();
    await auth.initialize();
    await auth.linkGoogle();
    api.id = 'employee-b';
    api.row = {'id': api.id, 'is_active': true, 'role': 'admin'};
    await auth.recheck();
    expect(auth.status, EmployeeAuthStatus.signedOut);
    expect(api.id, isNull);
  });
  test('identity conflicts are actionable without account merging', () {
    expect(
      authErrorMessage(
        const AuthException('private', code: 'identity_already_exists'),
      ),
      contains('người dùng khác'),
    );
  });
  test('logout cache operation removes all employee business data', () {
    final store = AppStore.seeded();
    expect(store.products, isNotEmpty);
    store.clearEmployeeData();
    expect(store.products, isEmpty);
    expect(store.partners, isEmpty);
    expect(store.documents, isEmpty);
    expect(store.invoices, isEmpty);
    expect(store.movements, isEmpty);
    expect(store.company.bank, isEmpty);
    store.dispose();
  });
}
