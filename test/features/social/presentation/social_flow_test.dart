import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/app.dart';
import 'package:squadly/features/social/presentation/screens/share_composer_screen.dart';

void main() {
  testWidgets(
    'personal demo data requires audience confirmation before sharing',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: SquadlyApp()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, '邮箱'),
        'haiming@example.com',
      );
      await tester.enterText(find.widgetWithText(TextField, '密码'), 'password1');
      await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('分享').last);
      await tester.pumpAndSettle();
      expect(find.text('制作分享'), findsOneWidget);
      expect(find.textContaining('未连接真实健康账户'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '我的新记录');
      await tester.tap(find.text('预览并确认发布'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('小队所有成员'),
        260,
        scrollable: find
            .descendant(
              of: find.byType(ShareComposerScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('请选择谁能看到这条分享'), findsOneWidget);
      expect(find.text('确认发布这条分享？'), findsNothing);

      await tester.tap(find.text('小队所有成员'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('预览并确认发布'));
      await tester.pumpAndSettle();
      expect(find.text('确认发布这条分享？'), findsOneWidget);
      expect(find.textContaining('接收者：'), findsOneWidget);

      await tester.tap(find.text('确认发布'));
      await tester.pumpAndSettle();
      expect(find.text('我的新记录'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
