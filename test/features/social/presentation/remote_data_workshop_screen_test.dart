import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/app/providers/activity_source_providers.dart';
import 'package:squadly/app/providers/current_user_provider.dart';
import 'package:squadly/app/providers/domain_repository_providers.dart';
import 'package:squadly/app/providers/social_providers.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/features/activity_import/data/health_connect_activity_source.dart';
import 'package:squadly/features/activity_import/domain/activity_record.dart';
import 'package:squadly/features/activity_import/domain/activity_source.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/social/domain/entities/data_connection.dart';
import 'package:squadly/features/social/domain/entities/external_data_item.dart';
import 'package:squadly/features/social/domain/entities/social_post.dart';
import 'package:squadly/features/social/domain/repositories/social_repository.dart';
import 'package:squadly/features/social/presentation/screens/data_workshop_screen.dart';

void main() {
  for (final phase in ['source', 'source-return', 'choice', 'choice-return']) {
    testWidgets(
      'account switch during health $phase never imports for the new account',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final identity = StateProvider<User?>((ref) => _user);
        final pendingRecords = Completer<List<ActivityRecord>>();
        final repository = _FakeSocialRepository();
        final container = ProviderContainer(
          overrides: [
            useDemoBackendProvider.overrideWithValue(false),
            currentUserProvider.overrideWith(
              (ref) => AsyncData(ref.watch(identity)),
            ),
            myImportedSocialDataProvider.overrideWith((ref) async => const []),
            mySocialConnectionsProvider.overrideWith((ref) async => const []),
            healthActivityAvailableProvider.overrideWith((ref) async => true),
            healthActivitySourceProvider.overrideWith(
              (ref) => _FakeActivitySource(
                listResult: phase.startsWith('source')
                    ? pendingRecords.future
                    : null,
              ),
            ),
            socialRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(
                body: DataWorkshopScreen(onShareItem: _share),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('单次导入 Apple 健康 的运动记录'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        VoidCallback? originalSelection;
        if (phase.startsWith('choice')) {
          originalSelection = tester
              .widget<ListTile>(
                find.ancestor(
                  of: find.textContaining('跑步 · 5.00 公里'),
                  matching: find.byType(ListTile),
                ),
              )
              .onTap!;
        }
        container.read(identity.notifier).state = _user.copyWith(id: 'user-b');
        if (phase.endsWith('return')) {
          await tester.pump(const Duration(milliseconds: 400));
          container.read(identity.notifier).state = _user;
          await tester.pump(const Duration(milliseconds: 400));
        }
        if (phase.startsWith('source')) {
          pendingRecords.complete([_activity]);
        } else {
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.textContaining('跑步 · 5.00 公里'), findsNothing);
          expect(find.text('账号已变化，请重新导入'), findsOneWidget);
          originalSelection!();
        }
        await tester.pumpAndSettle();

        expect(repository.items, isEmpty);
        expect(find.text('选择一条运动记录导入'), findsNothing);
        expect(find.text('账号已变化，请重新导入'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'stale private items and connections disappear when the account changes',
    (tester) async {
      final identity = StateProvider<User?>((ref) => _user);
      final container = ProviderContainer(
        overrides: [
          useDemoBackendProvider.overrideWithValue(false),
          currentUserProvider.overrideWith(
            (ref) => AsyncData(ref.watch(identity)),
          ),
          myImportedSocialDataProvider.overrideWith(
            (ref) async => [_privateItem],
          ),
          mySocialConnectionsProvider.overrideWith(
            (ref) async => [
              DataConnection(
                id: 'connection-a',
                userId: 'user-a',
                provider: 'apple_health',
                displayName: '伙伴甲的个人健康来源',
                mode: 'file_import',
                isConnected: false,
              ),
            ],
          ),
          healthActivityAvailableProvider.overrideWith((ref) async => false),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: DataWorkshopScreen(onShareItem: _share)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_privateItem.title), findsOneWidget);
      expect(find.text('伙伴甲的个人健康来源'), findsOneWidget);

      container.read(identity.notifier).state = _user.copyWith(id: 'user-b');
      await tester.pumpAndSettle();
      expect(find.text(_privateItem.title), findsNothing);
      expect(find.text(_privateItem.summary), findsNothing);
      expect(find.text('伙伴甲的个人健康来源'), findsNothing);
      expect(find.text('还没有个人素材'), findsOneWidget);
    },
  );

  testWidgets('remote workshop clearly shows unconnected health sources', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          useDemoBackendProvider.overrideWith((ref) => false),
          currentUserProvider.overrideWith((ref) => AsyncData(_user)),
          myImportedSocialDataProvider.overrideWith((ref) async => const []),
          mySocialConnectionsProvider.overrideWith((ref) async => const []),
          healthActivityAvailableProvider.overrideWith((ref) async => false),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DataWorkshopScreen(onShareItem: _share)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('没有持续同步连接'), findsOneWidget);
    expect(find.text('你可以按需授权并单次导入一条运动记录。'), findsOneWidget);
    expect(find.text('此设备暂不支持健康数据读取'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '此设备暂不支持健康数据读取'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('还没有个人素材'), findsOneWidget);
    expect(find.text('制作单次分享'), findsNothing);
  });

  testWidgets('imports one user-selected Apple Health record as private data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeSocialRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          useDemoBackendProvider.overrideWith((ref) => false),
          myImportedSocialDataProvider.overrideWith(
            (ref) async => repository.items,
          ),
          mySocialConnectionsProvider.overrideWith((ref) async => const []),
          healthActivityAvailableProvider.overrideWith((ref) async => true),
          healthActivitySourceProvider.overrideWith(
            (ref) => _FakeActivitySource(),
          ),
          currentUserProvider.overrideWith((ref) => AsyncData(_user)),
          socialRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: DataWorkshopScreen(onShareItem: _share)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('单次导入 Apple 健康 的运动记录'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('选择一条运动记录导入'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('跑步 · 5.00 公里'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.textContaining('跑步 · 5.00 公里'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(repository.items, hasLength(1));
    expect(repository.items.single.userId, 'user-a');
    expect(repository.items.single.source, 'apple_health');
    expect(repository.items.single.value, '5.00');
    expect(find.text('已导入个人素材；需要再次确认才会分享给小队'), findsOneWidget);
  });

  testWidgets(
    'maps a Health Connect workout and imports the selected record privately',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final startedAt = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch,
      );
      final endedAt = DateTime.fromMillisecondsSinceEpoch(
        startedAt.add(const Duration(minutes: 45)).millisecondsSinceEpoch,
      );
      const channel = MethodChannel('squadly/health_connect');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'isAvailable') return true;
            if (call.method == 'readWorkouts') {
              return [
                {
                  'id': 'health-connect-hike-1',
                  'kind': 'hike',
                  'startedAtMillis': startedAt.millisecondsSinceEpoch,
                  'endedAtMillis': endedAt.millisecondsSinceEpoch,
                  'distanceMeters': 4500.0,
                },
              ];
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final repository = _FakeSocialRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            useDemoBackendProvider.overrideWith((ref) => false),
            myImportedSocialDataProvider.overrideWith(
              (ref) async => repository.items,
            ),
            mySocialConnectionsProvider.overrideWith((ref) async => const []),
            healthActivityAvailableProvider.overrideWith((ref) async => true),
            healthActivitySourceLabelProvider.overrideWith(
              (ref) => 'Health Connect',
            ),
            healthActivitySourceProvider.overrideWith(
              (ref) => HealthConnectActivitySource(isAndroid: true),
            ),
            currentUserProvider.overrideWith((ref) => AsyncData(_user)),
            socialRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(body: DataWorkshopScreen(onShareItem: _share)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('单次导入 Health Connect 的运动记录'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('选择一条运动记录导入'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('徒步 · 4.50 公里'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.textContaining('徒步 · 4.50 公里'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(repository.items, hasLength(1));
      expect(repository.items.single.userId, 'user-a');
      expect(repository.items.single.source, 'health_connect');
      expect(repository.items.single.value, '4.50');
      expect(repository.items.single.unit, '公里');
      expect(repository.items.single.title, contains('徒步'));
      expect(repository.items.single.summary, contains('4.50 公里'));
      expect(repository.items.single.rangeStart, startedAt);
      expect(repository.items.single.rangeEnd, endedAt);
      expect(find.text('已导入个人素材；需要再次确认才会分享给小队'), findsOneWidget);
    },
  );
}

void _share(String _) {}

final _user = User(
  id: 'user-a',
  nickname: '伙伴甲',
  createdAt: DateTime.utc(2026, 1, 1),
);

final class _FakeActivitySource implements ActivitySource {
  _FakeActivitySource({ActivityRecord? activity, this.listResult})
    : activity = activity ?? _activity;

  final ActivityRecord activity;
  final Future<List<ActivityRecord>>? listResult;

  @override
  Future<List<ActivityRecord>> listEligibleActivities({
    required DateTime from,
    required DateTime to,
  }) async => listResult == null ? [activity] : await listResult!;

  @override
  Future<ActivityRecord> readActivity(String id) async => activity;

  @override
  Future<ActivityRecord> readPreciseRoute(ActivityRecord selected) async =>
      selected;
}

final _activity = ActivityRecord(
  id: 'activity-1',
  source: ActivitySourceKind.appleHealth,
  kind: ActivityKind.run,
  startedAt: DateTime.utc(2026, 10, 17, 8),
  utcOffsetMinutes: 480,
  distanceMeters: 5000,
  durationSeconds: 1800,
  sourceLabel: 'Apple Watch',
);

final _privateItem = ExternalDataItem(
  id: 'private-material-a',
  userId: 'user-a',
  source: 'apple_health',
  sourceLabel: 'Apple Watch',
  category: 'activity',
  title: '伙伴甲的私有运动',
  summary: '仅伙伴甲本人可见的运动摘要',
  value: '5.00',
  unit: '公里',
  rangeStart: DateTime.utc(2026, 10, 17),
  rangeEnd: DateTime.utc(2026, 10, 17, 1),
  importedAt: DateTime.utc(2026, 10, 17),
);

final class _FakeSocialRepository implements SocialRepository {
  final List<ExternalDataItem> items = [];

  @override
  Future<Either<Failure, List<ExternalDataItem>>> getMyImportedData() async =>
      right(List.unmodifiable(items));

  @override
  Future<Either<Failure, List<DataConnection>>> getMyConnections() async =>
      right(const []);

  @override
  Future<Either<Failure, ExternalDataItem>> importDataItem({
    required ExternalDataItem item,
  }) async {
    final saved = item.copyWith(id: 'saved-item');
    items.add(saved);
    return right(saved);
  }

  @override
  Stream<Either<Failure, List<SocialPost>>> watchPosts(String squadId) =>
      Stream.value(right(const []));

  @override
  Future<Either<Failure, SocialPost>> publishDataPost({
    required String squadId,
    required String dataItemId,
    required String title,
    required String body,
    required String template,
    required String visibility,
    List<String> visibleToUserIds = const [],
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, bool>> togglePostReaction({
    required String postId,
    required String squadId,
  }) async => throw UnimplementedError();
}
