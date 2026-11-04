import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:packflow/app.dart';
import 'package:packflow/data/app_store.dart';

void main() {
  testWidgets('PackFlow dashboard smoke test', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppStore.seeded(),
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Minh'), findsOneWidget);
    expect(find.text('Tổng quan'), findsOneWidget);
    expect(find.text('Nhập sản phẩm'), findsWidgets);
  });
}
