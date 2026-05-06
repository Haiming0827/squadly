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

    expect(find.text('小队'), findsOneWidget);
    expect(find.text('健身'), findsOneWidget);
    expect(find.text('理财'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('美食'), findsOneWidget);
    expect(find.text('周末行动组'), findsWidgets);
  });
}
