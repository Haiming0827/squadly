import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/app.dart';

void main() {
  testWidgets('demo login opens home shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SquadlyApp()));
    await tester.pumpAndSettle();

    expect(find.text('小分队'), findsWidgets);
    expect(find.text('邮箱登录'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '邮箱'),
      'haiming@example.com',
    );
    await tester.enterText(find.widgetWithText(TextField, '密码'), 'password1');
    await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('小队'), findsWidgets);
    expect(find.text('数据'), findsOneWidget);
    expect(find.text('分享'), findsOneWidget);
    expect(find.text('计划'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('周末行动组'), findsWidgets);

    await tester.tap(find.text('数据'));
    await tester.pumpAndSettle();
    expect(find.text('数据工坊'), findsOneWidget);
    expect(find.textContaining('演示导入样本'), findsOneWidget);

    await tester.tap(find.text('计划'));
    await tester.pumpAndSettle();
    expect(find.text('一起做点什么'), findsOneWidget);
    expect(find.text('健身'), findsOneWidget);
    expect(find.text('理财'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('美食'), findsOneWidget);
  });

  testWidgets('signing out returns to login without framework errors', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SquadlyApp()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '邮箱'),
      'haiming@example.com',
    );
    await tester.enterText(find.widgetWithText(TextField, '密码'), 'password1');
    await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text('深色'), matching: find.byType(ChoiceChip)),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('外观'))).brightness,
      Brightness.dark,
    );
    await tester.tap(
      find.ancestor(of: find.text('浅色'), matching: find.byType(ChoiceChip)),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('外观'))).brightness,
      Brightness.light,
    );
    await tester.ensureVisible(find.text('退出登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(find.text('邮箱登录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
