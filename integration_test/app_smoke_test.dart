import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:squadly/app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login and navigate primary tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SquadlyApp()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(EditableText).at(0),
      'haiming@example.com',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'password1');
    await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
    await tester.pumpAndSettle();

    for (final tab in ['健身', '理财', '旅行', '美食', '小队']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.text(tab), findsWidgets);
    }
  });
}
