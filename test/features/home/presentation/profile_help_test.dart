import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/home/presentation/screens/help_screen.dart';
import 'package:squadly/features/home/presentation/screens/profile_settings_screen.dart';

void main() {
  testWidgets('notification settings are user initiated', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProfileSettingsScreen(
              section: ProfileSettingsSection.appearance,
              onManageNotifications: () => opened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final settings = find.text('通知设置');
    expect(settings, findsOneWidget);
    await tester.tap(settings);
    expect(opened, isTrue);
  });

  testWidgets('profile opens help and expands confirmed product guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ProfileSettingsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('使用帮助'));
    await tester.tap(find.text('使用帮助'));
    await tester.pumpAndSettle();

    expect(find.text('常见问题'), findsOneWidget);
    const question = '如何加入小队？';
    await tester.ensureVisible(find.text(question));
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();

    expect(find.text(question), findsOneWidget);
    expect(find.text('小队采用邀请制，每个小队有 2–9 位成员。请让当前成员邀请你加入。'), findsOneWidget);
  });

  testWidgets('help remains usable on a narrow dark screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: HelpScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const question = '演示数据代表已连接健康服务吗？';
    await tester.ensureVisible(find.text(question));
    await tester.tap(find.text(question));
    await tester.pumpAndSettle();

    expect(
      find.text('不代表。若页面标注为演示数据，内容用于体验功能，不表示已连接或同步外部健康服务。'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
