import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../auth/auth_service.dart';
import '../data/app_store.dart';
import '../features/screens.dart';
import '../features/sales_orders.dart';

const taskPaths = [
  '/dashboard',
  '/products',
  '/inventory',
  '/invoices',
  '/inbound',
  '/outbound',
  '/sales-orders',
  '/partners',
  '/reports',
  '/settings',
];
const authPaths = ['/', '/login', '/loading', '/unauthorized', '/auth-error'];

GoRouter createAppRouter(
  AuthController? auth, {
  String? configurationError,
  String? initialLocation,
}) {
  var destination = '/dashboard';
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: auth,
    redirect: (context, state) {
      if (configurationError != null) return state.uri.path == '/' ? null : '/';
      final path = state.uri.path;
      final protected = !authPaths.contains(path);
      if (protected) destination = state.uri.toString();
      final target = switch (auth!.status) {
        EmployeeAuthStatus.initializing ||
        EmployeeAuthStatus.checking => '/loading',
        EmployeeAuthStatus.signedOut ||
        EmployeeAuthStatus.authenticating => '/login',
        EmployeeAuthStatus.unauthorized => '/unauthorized',
        EmployeeAuthStatus.failure => '/auth-error',
        EmployeeAuthStatus.signedIn => protected ? path : destination,
      };
      return path == target ? null : target;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => configurationError != null
            ? ConfigurationScreen(message: configurationError)
            : const AuthGate(),
      ),
      for (final path in authPaths.skip(1))
        GoRoute(path: path, builder: (_, _) => const AuthGate()),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const AuthGate(child: AppShell()),
      ),
      GoRoute(
        path: '/products',
        builder: (_, _) => const AuthGate(
          child: AppShell(routePath: '/products', content: ProductsScreen()),
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) => const AuthGate(child: ProductFormScreen()),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => AuthGate(
              child: RecordPage(
                kind: 'product',
                id: state.pathParameters['id']!,
              ),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) => AuthGate(
                  child: RecordPage(
                    kind: 'product',
                    id: state.pathParameters['id']!,
                    edit: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/inventory',
        builder: (_, _) => const AuthGate(
          child: AppShell(routePath: '/inventory', content: InventoryScreen()),
        ),
      ),
      GoRoute(
        path: '/invoices',
        builder: (_, _) => const AuthGate(
          child: AppShell(routePath: '/invoices', content: InvoicesScreen()),
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) => const AuthGate(child: InvoiceFormScreen()),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => AuthGate(
              child: RecordPage(
                kind: 'invoice',
                id: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),
      for (final inbound in [true, false])
        GoRoute(
          path: inbound ? '/inbound' : '/outbound',
          redirect: (_, state) => inbound ? '/products' : null,
          builder: (_, _) => AuthGate(
            child: AppShell(
              routePath: inbound ? '/inbound' : '/outbound',
              content: DocumentsScreen(inbound: inbound),
            ),
          ),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, state) => AuthGate(
                child: DocumentFormScreen(
                  inbound: inbound,
                  productId: state.uri.queryParameters['productId'],
                ),
              ),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) => AuthGate(
                child: RecordPage(
                  kind: inbound ? 'inbound' : 'outbound',
                  id: state.pathParameters['id']!,
                ),
              ),
            ),
          ],
        ),
      GoRoute(
        path: '/sales-orders',
        builder: (_, _) => const AuthGate(
          child: AppShell(
            routePath: '/sales-orders',
            content: SalesOrdersScreen(),
          ),
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) => const AuthGate(child: SalesOrderFormScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/partners',
        builder: (_, _) => const AuthGate(
          child: AppShell(routePath: '/partners', content: PartnersScreen()),
        ),
      ),
      GoRoute(
        path: '/reports',
        builder: (_, _) => const AuthGate(
          child: AppShell(routePath: '/reports', content: ReportsScreen()),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const AuthGate(
          child: AppShell(routePath: '/settings', content: SettingsScreen()),
        ),
      ),
    ],
    errorBuilder: (_, _) => const AuthGate(child: MissingPage()),
  );
}

class RecordPage extends StatelessWidget {
  const RecordPage({
    super.key,
    required this.kind,
    required this.id,
    this.edit = false,
  });
  final String kind, id;
  final bool edit;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (store.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (store.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: store.loadRemoteData,
            child: const Text('Tải lại dữ liệu'),
          ),
        ),
      );
    }
    if (kind == 'product') {
      final product = store.products.where((p) => p.id == id).firstOrNull;
      if (product != null) {
        return edit
            ? ProductFormScreen(key: ValueKey(id), product: product)
            : ProductDetailScreen(product);
      }
    } else if (kind == 'invoice') {
      final invoice = store.invoices.where((p) => p.id == id).firstOrNull;
      if (invoice != null) return InvoiceDetailScreen(invoice);
    } else {
      final document = store.documents
          .where((p) => p.id == id && p.inbound == (kind == 'inbound'))
          .firstOrNull;
      if (document != null) return DocumentDetailScreen(document);
    }
    return const MissingPage();
  }
}

class MissingPage extends StatelessWidget {
  const MissingPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Không tìm thấy')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Đường dẫn hoặc dữ liệu không tồn tại.'),
          TextButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text('Về tổng quan'),
          ),
        ],
      ),
    ),
  );
}
