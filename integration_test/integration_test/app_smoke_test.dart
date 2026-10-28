import 'dart:io' show Platform;

import 'package:cloudbase_flutter/cloudbase_flutter.dart' hide CloudBaseConfig;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:squadly/app/app.dart';
import 'package:squadly/app/providers/activity_source_providers.dart';
import 'package:squadly/core/config/cloudbase_config.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/core/theme/theme_mode_provider.dart';
import 'package:squadly/features/activity_import/data/apple_health_activity_source.dart';
import 'package:squadly/features/activity_import/data/health_connect_activity_source.dart';
import 'package:squadly/features/activity_import/domain/activity_source.dart';
import 'package:squadly/features/social/presentation/screens/share_composer_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('appearance preference survives app provider recreation', (
    tester,
  ) async {
    final store = SharedPreferencesThemeModeStore();
    await store.write(ThemeMode.system.name);

    final firstContainer = ProviderContainer();
    final firstController = firstContainer.read(themeModeProvider.notifier);
    await firstController.initialized;
    await firstController.select(ThemeMode.dark);
    firstContainer.dispose();

    final restoredContainer = ProviderContainer();
    try {
      await restoredContainer.read(themeModeProvider.notifier).initialized;
      expect(restoredContainer.read(themeModeProvider), ThemeMode.dark);
    } finally {
      await restoredContainer
          .read(themeModeProvider.notifier)
          .select(ThemeMode.system);
      restoredContainer.dispose();
    }
  });

  testWidgets('demo login and primary navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SquadlyApp()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(EditableText).at(0),
      'haiming@example.com',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'password1');
    await _tapVisible(tester, find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    for (final tab in ['会话', '小队', '计划', '我的']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.text(tab), findsWidgets);
    }

    await tester.tap(find.text('计划').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(find.text('第 1 步 · 基本信息'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '设备冒烟计划');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 步 · 协作设置'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '创建计划'));
    await tester.pumpAndSettle();
    expect(find.text('设备冒烟计划'), findsOneWidget);
    expect(find.text('当前小队成员可以查看此计划和其中的任务。'), findsOneWidget);
    Navigator.of(tester.element(find.text('计划详情'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '仅自己可见的设备计划');
    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('当前小队可见'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仅自己可见').last);
    await tester.pumpAndSettle();
    expect(find.text('计划仍关联当前小队，仅你可以查看。'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '创建计划'));
    await tester.pumpAndSettle();
    expect(find.text('仅自己可见的设备计划'), findsOneWidget);
    expect(find.text('仅自己可见'), findsWidgets);
    expect(find.text('仅你可以查看此计划和其中的任务。计划仍归属当前小队。'), findsOneWidget);
    Navigator.of(tester.element(find.text('计划详情'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '健身'));
    await tester.pumpAndSettle();
    expect(find.text('健身'), findsWidgets);
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('USE_DEMO_BACKEND', defaultValue: true));

  testWidgets('demo sharing requires audience review and explicit publish', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SquadlyApp()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).at(0),
      'haiming@example.com',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'password1');
    await _tapVisible(tester, find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('小队').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('分享一件新鲜事'));
    await tester.pumpAndSettle();
    expect(find.text('制作分享'), findsOneWidget);
    expect(find.textContaining('未连接真实健康账户'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '设备单次分享验收');
    await tester.tap(find.text('预览并确认发布'));
    await tester.pumpAndSettle();
    final audienceChoice = find.text('小队所有成员');
    await tester.scrollUntilVisible(
      audienceChoice,
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

    await tester.tap(audienceChoice);
    await tester.pumpAndSettle();
    await tester.tap(find.text('预览并确认发布'));
    await tester.pumpAndSettle();
    expect(find.text('确认发布这条分享？'), findsOneWidget);
    expect(find.text('只发布当前预览的内容，之后的数据变化不会自动同步到这条分享。'), findsOneWidget);
    await tester.tap(find.text('确认发布'));
    await tester.pumpAndSettle();
    expect(find.text('设备单次分享验收'), findsWidgets);
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('USE_DEMO_BACKEND', defaultValue: true));

  testWidgets('CloudBase mode restores session and opens the login screen', (
    tester,
  ) async {
    final config = CloudBaseConfig.fromEnvironment();
    expect(config.useDemo, isFalse);
    final cloudBase = await CloudBase.init(
      env: config.environmentId,
      region: config.region,
      accessKey: config.publishableKey,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [cloudBaseAppProvider.overrideWithValue(cloudBase)],
        child: const SquadlyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('邮箱登录'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('数据'), findsNothing);
  }, skip: const bool.fromEnvironment('USE_DEMO_BACKEND', defaultValue: true));

  testWidgets('Android Health Connect bridge reports provider availability', (
    tester,
  ) async {
    if (!Platform.isAndroid) return;
    const channel = MethodChannel('squadly/health_connect');
    final available = await channel.invokeMethod<bool>('isAvailable');
    expect(available, isTrue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      await container.read(healthActivityAvailableProvider.future),
      isTrue,
    );
  }, skip: !const bool.fromEnvironment('VERIFY_HEALTH_CONNECT'));

  testWidgets(
    'Android Health Connect bridge reports unavailable when provider is missing',
    (tester) async {
      if (!Platform.isAndroid) return;
      const channel = MethodChannel('squadly/health_connect');
      expect(await channel.invokeMethod<bool>('isAvailable'), isFalse);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        await container.read(healthActivityAvailableProvider.future),
        isFalse,
      );

      // Exercise the real native rejection as well as the availability hint.
      // A caller bypassing the disabled import control must fail safely before
      // requesting permissions or trying to construct a Health Connect client.
      final now = DateTime.now();
      await expectLater(
        MethodChannelHealthConnectGateway(channel: channel)
            .readWorkouts(now.subtract(const Duration(days: 1)), now),
        throwsA(isA<ActivitySourceUnavailable>()),
      );
    },
    skip: !const bool.fromEnvironment('VERIFY_HEALTH_CONNECT_UNAVAILABLE'),
  );

  testWidgets(
    'Android Health Connect requests consent and reads workout summaries',
    (tester) async {
      if (!Platform.isAndroid) return;
      final now = DateTime.now();
      final channel = const MethodChannel('squadly/health_connect');
      final arguments = {
        'fromMillis': now
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch,
        'toMillis': now.millisecondsSinceEpoch,
      };
      final records = await channel.invokeListMethod<Object?>(
        'readWorkouts',
        arguments,
      );
      expect(records, isNotNull);
      final subsequentRead = await channel.invokeListMethod<Object?>(
        'readWorkouts',
        arguments,
      );
      expect(subsequentRead, isNotNull);
    },
    skip: !const bool.fromEnvironment('VERIFY_HEALTH_CONNECT_READ'),
  );

  testWidgets(
    'mocked Android Health Connect workout maps to a private activity record',
    (tester) async {
      if (!Platform.isAndroid) return;
      final startedAt = DateTime.now().subtract(const Duration(days: 2));
      final endedAt = startedAt.add(const Duration(minutes: 42));
      const channel = MethodChannel('squadly/health_connect');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'isAvailable') return true;
            if (call.method == 'readWorkouts') {
              return [
                {
                  'id': 'integration-health-connect-run',
                  'kind': 'run',
                  'startedAtMillis': startedAt.millisecondsSinceEpoch,
                  'endedAtMillis': endedAt.millisecondsSinceEpoch,
                  'distanceMeters': 6250.0,
                },
              ];
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final source = HealthConnectActivitySource();
      final records = await source.listEligibleActivities(
        from: startedAt.subtract(const Duration(minutes: 1)),
        to: endedAt.add(const Duration(minutes: 1)),
      );
      expect(records, hasLength(1));
      expect(records.single.id, 'integration-health-connect-run');
      expect(records.single.kind.name, 'run');
      expect(records.single.distanceMeters, 6250);
      expect(records.single.durationSeconds, 42 * 60);
      expect(records.single.sourceLabel, 'Health Connect');
      expect(await source.readActivity(records.single.id), records.single);
    },
    skip: !const bool.fromEnvironment('VERIFY_HEALTH_CONNECT_IMPORT'),
  );

  testWidgets(
    'iOS Apple Health requests read access and supports repeated workout reads',
    (tester) async {
      if (!Platform.isIOS) return;
      final source = AppleHealthActivitySource();
      final to = DateTime.now();
      final from = to.subtract(const Duration(days: 30));

      final firstRead = await source.listEligibleActivities(from: from, to: to);
      final secondRead = await source.listEligibleActivities(
        from: from,
        to: to,
      );

      expect(
        secondRead.map((record) => record.id).toList(),
        firstRead.map((record) => record.id).toList(),
      );
    },
    skip: !const bool.fromEnvironment('VERIFY_APPLE_HEALTH_READ'),
  );
}

/// Native IME resize and focus scrolling can arrive after pumpAndSettle has
/// stopped scheduling frames. Reach the actual control, then require a hit
/// before tapping; a clipped or obstructed control must still fail the test.
Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    if (target.hitTestable().evaluate().length == 1) {
      await tester.tap(target);
      return;
    }
  }
  fail('Control did not become reachable after scrolling and layout updates.');
}
