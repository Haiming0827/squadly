import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/app/providers/current_user_provider.dart';
import 'package:squadly/app/providers/domain_repository_providers.dart';
import 'package:squadly/app/providers/social_providers.dart';
import 'package:squadly/app/providers/squad_context_providers.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/social/domain/entities/data_connection.dart';
import 'package:squadly/features/social/domain/entities/external_data_item.dart';
import 'package:squadly/features/social/domain/entities/social_post.dart';
import 'package:squadly/features/social/domain/repositories/social_repository.dart';
import 'package:squadly/features/social/presentation/screens/remote_share_composer_screen.dart';
import 'package:squadly/features/squad/domain/entities/squad.dart';
import 'package:squadly/features/squad/domain/entities/squad_member.dart';

void main() {
  for (final changedContext in [
    'account',
    'account-return',
    'squad',
    'recipient',
  ]) {
    testWidgets('revalidates $changedContext after snapshot confirmation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final identity = StateProvider<User?>((ref) => _user);
      final selectedSquad = StateProvider<Squad>((ref) => _squad);
      final membership = StateProvider<List<SquadMember>>(
        (ref) => [_captain, _member],
      );
      final repository = _FakeSocialRepository();
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => AsyncData(ref.watch(identity)),
          ),
          currentSquadProvider.overrideWith(
            (ref) => AsyncData(ref.watch(selectedSquad)),
          ),
          myImportedSocialDataProvider.overrideWith((ref) async => [_item]),
          squadMembersProvider(_squad.id)
              .overrideWith((ref) async => ref.watch(membership)),
          squadMembersProvider('squad-2').overrideWith((ref) async => const []),
          socialRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const RemoteShareComposerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('指定成员'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('伙伴乙'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('预览并确认发布'));
      await tester.pumpAndSettle();
      expect(find.text('确认发布这条分享？'), findsOneWidget);
      final originalConfirm = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认发布'))
          .onPressed!;

      switch (changedContext) {
        case 'account':
          container.read(identity.notifier).state = _user.copyWith(
            id: 'user-b',
          );
        case 'account-return':
          container.read(identity.notifier).state = _user.copyWith(
            id: 'user-b',
          );
          await tester.pumpAndSettle();
          container.read(identity.notifier).state = _user;
        case 'squad':
          container.read(selectedSquad.notifier).state = _squad.copyWith(
            id: 'squad-2',
            name: '另一小队',
          );
        case 'recipient':
          container.read(membership.notifier).state = [_captain];
      }
      await tester.pumpAndSettle();
      expect(find.text('分享上下文已变化'), findsOneWidget);
      // A callback retained before the context change must also be rejected.
      originalConfirm();
      await tester.pumpAndSettle();

      expect(repository.publishCount, 0);
      expect(find.text('账号、小队或接收成员已变化，请重新预览后发布'), findsOneWidget);
      if (changedContext == 'account') {
        expect(find.text(_item.title), findsNothing);
        expect(find.text(_item.summary), findsNothing);
        expect(find.textContaining(_item.value), findsNothing);
      }
    });
  }

  testWidgets(
    'requires an audience and confirms one-time snapshot before RPC',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeSocialRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myImportedSocialDataProvider.overrideWith((ref) async => [_item]),
            currentSquadProvider.overrideWith((ref) => AsyncData(_squad)),
            squadMembersProvider(_squad.id)
                .overrideWith((ref) async => [_captain, _member]),
            currentUserProvider.overrideWith((ref) => AsyncData(_user)),
            socialRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const RemoteShareComposerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('分享至 周末小队'), findsOneWidget);

      await tester.tap(find.text('预览并确认发布'));
      await tester.pumpAndSettle();
      expect(repository.publishCount, 0);
      expect(find.text('请选择分享范围'), findsOneWidget);

      await tester.tap(find.text('指定成员'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('伙伴乙'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('预览并确认发布'));
      await tester.pumpAndSettle();
      expect(find.textContaining('接收者：伙伴乙'), findsOneWidget);
      expect(find.textContaining('来源数据变化不会更新'), findsOneWidget);

      await tester.tap(find.text('确认发布'));
      await tester.pumpAndSettle();
      expect(repository.publishCount, 1);
      expect(repository.lastVisibility, 'selected');
      expect(repository.lastRecipients, ['user-b']);
      expect(repository.lastDataItemId, _item.id);
      expect(find.text('制作分享'), findsNothing);
    },
  );

  testWidgets('fits the share composer on a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myImportedSocialDataProvider.overrideWith((ref) async => [_item]),
          currentSquadProvider.overrideWith((ref) => AsyncData(_squad)),
          squadMembersProvider(_squad.id)
              .overrideWith((ref) async => [_captain, _member]),
          currentUserProvider.overrideWith((ref) => AsyncData(_user)),
          socialRepositoryProvider.overrideWithValue(_FakeSocialRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 720),
              textScaler: TextScaler.linear(1.4),
            ),
            child: RemoteShareComposerScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('分享至 周末小队'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _user = User(
  id: 'user-a',
  nickname: '伙伴甲',
  createdAt: DateTime.utc(2026, 1, 1),
);

final _squad = Squad(
  id: 'squad-1',
  name: '周末小队',
  inviteCode: 'invite1',
  createdBy: 'user-a',
  createdAt: DateTime.utc(2026, 1, 1),
);

final _captain = SquadMember(
  id: 'member-a',
  squadId: 'squad-1',
  userId: 'user-a',
  role: 'captain',
  joinedAt: DateTime.utc(2026, 1, 1),
  nickname: '伙伴甲',
);

final _member = SquadMember(
  id: 'member-b',
  squadId: 'squad-1',
  userId: 'user-b',
  role: 'member',
  joinedAt: DateTime.utc(2026, 1, 1),
  nickname: '伙伴乙',
);

final _item = ExternalDataItem(
  id: 'item-1',
  userId: 'user-a',
  source: 'apple_health',
  sourceLabel: 'Apple 健康',
  category: 'steps',
  title: '今日步数',
  summary: '步行活跃',
  value: '8420',
  unit: '步',
  rangeStart: DateTime.utc(2026, 10, 18),
  rangeEnd: DateTime.utc(2026, 10, 18, 23, 59),
  importedAt: DateTime.utc(2026, 10, 18),
);

final class _FakeSocialRepository implements SocialRepository {
  int publishCount = 0;
  String? lastVisibility;
  String? lastDataItemId;
  List<String> lastRecipients = const [];

  @override
  Future<Either<Failure, List<ExternalDataItem>>> getMyImportedData() async =>
      right([_item]);

  @override
  Future<Either<Failure, List<DataConnection>>> getMyConnections() async =>
      right(const []);

  @override
  Future<Either<Failure, ExternalDataItem>> importDataItem({
    required ExternalDataItem item,
  }) async => right(item);

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
  }) async {
    publishCount++;
    lastVisibility = visibility;
    lastDataItemId = dataItemId;
    lastRecipients = visibleToUserIds;
    return right(
      SocialPost(
        id: 'post-1',
        squadId: squadId,
        authorId: _user.id,
        authorName: _user.nickname,
        title: title,
        body: body,
        template: template,
        visibility: visibility,
        sourceLabel: _item.sourceLabel,
        metricValue: _item.value,
        metricUnit: _item.unit,
        rangeStart: _item.rangeStart,
        rangeEnd: _item.rangeEnd,
        createdAt: DateTime.utc(2026, 10, 18),
        visibleToUserIds: visibleToUserIds,
      ),
    );
  }

  @override
  Future<Either<Failure, bool>> togglePostReaction({
    required String postId,
    required String squadId,
  }) async => right(true);
}
