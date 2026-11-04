import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'core/app_router.dart';

import 'auth/auth_service.dart';
import 'auth/google_account.dart';
import 'data/app_store.dart';
import 'features/screens.dart';

class PackFlowApp extends StatefulWidget {
  const PackFlowApp({super.key, this.configurationError});
  final String? configurationError;
  @override
  State<PackFlowApp> createState() => _PackFlowAppState();
}

class _PackFlowAppState extends State<PackFlowApp> {
  GoRouter? _router;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= createAppRouter(
      widget.configurationError == null ? context.read<AuthController>() : null,
      configurationError: widget.configurationError,
    );
  }

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2563EB);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: Colors.white,
    ).copyWith(error: const Color(0xFFDC2626));
    return MaterialApp.router(
      routerConfig: _router,
      key: widget.configurationError == null
          ? ValueKey(
              context.select<AuthController, String>(
                (auth) =>
                    '${auth.status == EmployeeAuthStatus.signedIn}:${auth.employee?['id']}',
              ),
            )
          : const ValueKey('configuration'),
      debugShowCheckedModeBanner: false,
      title: 'PackFlow – Quản lý kho bao bì',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Arial',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          height: 72,
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFDBEAFE),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class ConfigurationScreen extends StatelessWidget {
  const ConfigurationScreen({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chưa cấu hình Supabase',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.child});
  final Widget? child;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthController>().recheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return switch (auth.status) {
      EmployeeAuthStatus.initializing || EmployeeAuthStatus.checking =>
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      EmployeeAuthStatus.signedOut ||
      EmployeeAuthStatus.authenticating => const LoginScreen(),
      EmployeeAuthStatus.signedIn => widget.child ?? const AppShell(),
      EmployeeAuthStatus.unauthorized => const UnauthorizedScreen(),
      EmployeeAuthStatus.failure => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(auth.message ?? 'Không thể kiểm tra quyền truy cập.'),
              FilledButton(
                onPressed: auth.recheck,
                child: const Text('Thử lại'),
              ),
              TextButton(
                onPressed: auth.signOut,
                child: const Text('Quay lại đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    };
  }
}

class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.admin_panel_settings_outlined,
              size: 64,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không có quyền truy cập',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.read<AuthController>().service.isGoogleSession
                  ? 'Tài khoản Google này chưa được cấp quyền sử dụng hệ thống. Vui lòng liên hệ quản trị viên.'
                  : 'Tài khoản này chưa được cấp quyền sử dụng hệ thống hoặc đã bị vô hiệu hóa. Vui lòng liên hệ quản trị viên.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: context.read<AuthController>().signOut,
              child: const Text('Quay lại đăng nhập'),
            ),
            OutlinedButton(
              onPressed: context.read<AuthController>().signOut,
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final identifier = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool hidePassword = true;
  String? error;

  Future<void> login() async {
    if (loading || context.read<AuthController>().busy) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final ok = await context.read<AuthController>().signIn(
        identifier.text,
        password.text,
      );
      if (!ok && mounted) {
        setState(() => error = context.read<AuthController>().message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Không thể kết nối máy chủ. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> recover() async {
    final recoveryEmail = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Khôi phục mật khẩu'),
        content: TextField(
          controller: recoveryEmail,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email đã xác minh'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Gửi liên kết'),
          ),
        ],
      ),
    );
    if (sent == true && mounted) {
      try {
        await context.read<AuthController>().recover(recoveryEmail.text);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nếu email hợp lệ, liên kết khôi phục sẽ được gửi.'),
          ),
        );
      }
    }
    recoveryEmail.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final pending = loading || auth.busy;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Đăng nhập PackFlow',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    'Hệ thống quản lý kho nội bộ',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: identifier,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập hoặc số điện thoại',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: hidePassword,
                    onSubmitted: (_) => login(),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => hidePassword = !hidePassword),
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (error != null || auth.message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error ?? auth.message!,
                        style: const TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: pending ? null : login,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Đăng nhập'),
                  ),
                  TextButton(
                    onPressed: pending ? null : recover,
                    child: const Text('Quên mật khẩu?'),
                  ),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('hoặc'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: pending
                        ? null
                        : context.read<AuthController>().google,
                    icon: auth.oauthPending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const GoogleMark(),
                    label: Text(
                      auth.oauthPending
                          ? 'Đang chờ Google…'
                          : 'Đăng nhập với Google',
                    ),
                  ),
                  if (auth.oauthPending)
                    TextButton(
                      onPressed: auth.cancelOAuth,
                      child: const Text('Hủy và quay lại đăng nhập'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.routePath = '/dashboard', this.content});
  final String routePath;
  final Widget? content;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  final pages = const [
    DashboardScreen(),
    ProductsScreen(),
    InventoryScreen(),
    InvoicesScreen(),
  ];
  void _more() => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tạo mới & Tiện ích',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _MoreItem(
              Icons.move_to_inbox_rounded,
              'Nhập sản phẩm',
              'Nhập hàng và cập nhật tồn kho',
              () => _open('/products/new'),
            ),
            _MoreItem(
              Icons.outbox_rounded,
              'Xuất kho',
              'Tạo phiếu xuất hàng',
              () => _open('/outbound'),
            ),
            _MoreItem(
              Icons.groups_rounded,
              'Đối tác',
              'Khách hàng và nhà cung cấp',
              () => _open('/partners'),
            ),
            _MoreItem(
              Icons.shopping_cart_checkout_rounded,
              'Đơn bán hàng',
              'Theo dõi yêu cầu và tiến độ xuất',
              () => _open('/sales-orders'),
            ),
            _MoreItem(
              Icons.bar_chart_rounded,
              'Báo cáo',
              'Phân tích kho và doanh số',
              () => _open('/reports'),
            ),
            _MoreItem(
              Icons.settings_rounded,
              'Cài đặt',
              'Thông tin doanh nghiệp',
              () => _open('/settings'),
            ),
            _MoreItem(
              Icons.logout_rounded,
              'Đăng xuất',
              'Kết thúc phiên làm việc',
              _logout,
            ),
          ],
        ),
      ),
    ),
  );
  void _open(String path) {
    Navigator.pop(context);
    context.go(path);
  }

  Future<void> _logout() async {
    Navigator.pop(context);
    await context.read<AuthController>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      body: Stack(
        children: [
          widget.content ?? IndexedStack(index: index, children: pages),
          if (store.loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (store.errorMessage != null)
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.paddingOf(context).top + 8,
              child: Material(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  textColor: Colors.white,
                  iconColor: Colors.white,
                  leading: const Icon(Icons.cloud_off),
                  title: Text(store.errorMessage!),
                  trailing: TextButton(
                    onPressed: store.loadRemoteData,
                    child: const Text(
                      'Thử lại',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.content == null
            ? index
            : switch (widget.routePath) {
                '/products' => 1,
                '/inventory' => 2,
                '/invoices' => 3,
                _ => 4,
              },
        onDestinationSelected: (value) {
          if (value == 4) {
            _more();
          } else {
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              router.go(
                ['/dashboard', '/products', '/inventory', '/invoices'][value],
              );
            } else {
              setState(() => index = value);
            }
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Nhập sản phẩm',
          ),
          NavigationDestination(
            icon: Icon(Icons.warehouse_outlined),
            selectedIcon: Icon(Icons.warehouse),
            label: 'Kho hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Hóa đơn',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Thêm',
          ),
        ],
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  const _MoreItem(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFDBEAFE),
      child: Icon(icon, color: const Color(0xFF2563EB)),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
  );
}
