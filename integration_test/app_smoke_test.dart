import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:squadly/app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo login and primary navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SquadlyApp()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(EditableText).at(0),
      'haiming@example.com',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'password1');
    await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
    await tester.pumpAndSettle();

    for (final tab in ['数据', '计划', '我的', '小队']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.text(tab), findsWidgets);
    }

    await tester.tap(find.text('计划').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('健身'));
    await tester.pumpAndSettle();
    expect(find.text('健身'), findsWidgets);
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('USE_DEMO_BACKEND', defaultValue: true));
}
