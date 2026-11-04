import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:packflow/auth/auth_service.dart';
import 'package:packflow/core/app_router.dart';
import 'package:packflow/data/app_store.dart';
import 'package:packflow/features/screens.dart';

import 'auth_controller_test.dart' show FakeAuth;

void main() {
  late FakeAuth api;
  setUp(() {
    api = FakeAuth();
  });
  tearDown(() async {
    await api.events.close();
    await api.client.dispose();
  });
  testWidgets(
    'direct detail URL waits for login, resolves ID and supports back',
    (tester) async {
      final auth = AuthController(api);
      final store = AppStore.seeded();
      await auth.recheck();
      final path = '/products/${Uri.encodeComponent(store.products.first.id)}';
      final router = createAppRouter(auth, initialLocation: path);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: store),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(find.byType(ProductDetailScreen), findsNothing);
      api.employee();
      await auth.recheck();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(find.byType(ProductDetailScreen), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/products');
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(find.byType(ProductsScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      auth.dispose();
      store.dispose();
    },
  );

  testWidgets(
    'each task and form has a resolvable URL and missing IDs do not crash',
    (tester) async {
      api.employee();
      final auth = AuthController(api);
      final store = AppStore.seeded();
      await auth.recheck();
      final router = createAppRouter(auth, initialLocation: '/dashboard');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: store),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      for (final path in [
        ...taskPaths,
        '/products/new',
        '/inbound/new',
        '/outbound/new',
        '/invoices/new',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          path.startsWith('/inbound') ? '/products' : path,
        );
        expect(find.byType(MissingPage), findsNothing, reason: path);
        expect(tester.takeException(), isNull, reason: path);
      }
      router.go('/products/not-a-real-id');
      await tester.pumpAndSettle();
      expect(find.byType(MissingPage), findsOneWidget);
      router.go('/not-a-real-page');
      await tester.pumpAndSettle();
      expect(find.byType(MissingPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      auth.dispose();
      store.dispose();
    },
  );

  testWidgets('empty master data and deleted references do not crash buttons', (
    tester,
  ) async {
    api.employee();
    final auth = AuthController(api);
    final store = AppStore.seeded();
    await auth.recheck();
    final router = createAppRouter(auth, initialLocation: '/inbound/new');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: store),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    store.clearEmployeeData();
    for (final path in ['/outbound/new', '/invoices/new']) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: path);
      expect(find.textContaining('Chưa có'), findsWidgets, reason: path);
    }

    store
      ..products.addAll(AppStore.seeded().products)
      ..partners.addAll(AppStore.seeded().partners)
      ..documents.addAll(AppStore.seeded().documents)
      ..invoices.addAll(AppStore.seeded().invoices)
      ..movements.addAll(AppStore.seeded().movements);
    store.products.removeWhere(
      (product) =>
          store.movements.any((movement) => movement.productId == product.id),
    );
    store.partners.clear();
    for (final path in ['/dashboard', '/inventory', '/inbound', '/invoices']) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: path);
    }

    await tester.pumpWidget(const SizedBox());
    router.dispose();
    auth.dispose();
    store.dispose();
  });
}
