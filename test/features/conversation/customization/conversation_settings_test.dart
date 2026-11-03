import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/app/providers/conversation_customization_providers.dart';
import 'package:squadly/app/providers/squad_context_providers.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/conversation/domain/conversation_preference.dart';
import 'package:squadly/features/conversation/presentation/conversation_settings_screen.dart';
import 'package:squadly/features/conversation/presentation/frequent_squads.dart';
import 'package:squadly/features/squad/domain/entities/squad.dart';
import 'package:squadly/features/squad/domain/entities/squad_member.dart';
import 'package:squadly/features/squad/domain/repositories/squad_profile_repository.dart';
import 'package:squadly/features/squad/domain/squad_avatar_format.dart';

final class _Preferences implements ConversationCustomizationRepository {
  String? remark;
  bool? pinned;
  bool fail = false;
  @override
  Future<Either<Failure, List<ConversationPreference>>> load() async =>
      right([]);
  @override
  Future<Either<Failure, void>> recordOpen(String squadId) async => right(null);
  @override
  Future<Either<Failure, void>> save({
    required String squadId,
    required String remark,
    required bool pinned,
  }) async {
    if (fail) return left(const Failure.server(message: '请稍后重试'));
    this.remark = remark;
    this.pinned = pinned;
    return right(null);
  }
}

final class _Profile implements SquadProfileRepository {
  String? name, avatar;
  @override
  Future<Either<Failure, void>> save({
    required String squadId,
    required String name,
    required String description,
    required String? avatar,
  }) async {
    this.name = name;
    this.avatar = avatar;
    return right(null);
  }
}

final class _Picker implements SquadAvatarPicker {
  _Picker(this.value);
  final String? value;
  @override
  Future<Either<Failure, String?>> pick() async => right(value);
}

Squad _squad(String id) => Squad(
  id: id,
  name: '小队$id',
  inviteCode: '',
  createdBy: 'alice',
  createdAt: DateTime(2026),
);
void main() {
  Future<void> show(
    WidgetTester tester, {
    required _Preferences prefs,
    required _Profile profile,
    bool captain = true,
    String? avatar,
  }) async {
    final squad = _squad('s');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customizationUserIdProvider.overrideWithValue('alice'),
          conversationCustomizationRepositoryProvider.overrideWithValue(prefs),
          conversationPreferencesProvider.overrideWith(
            (ref) => prefs.load().then((r) => r.getRight().toNullable()!),
          ),
          settingsSquadProvider('s').overrideWith((ref) async => squad),
          mySquadsProvider.overrideWith((ref) async => [squad]),
          settingsMembersProvider('s').overrideWith(
            (ref) async => [
              SquadMember(
                id: 'm',
                squadId: 's',
                userId: 'alice',
                role: captain ? 'captain' : 'member',
                nickname: '阿青',
                joinedAt: DateTime(2026),
              ),
            ],
          ),
          squadProfileRepositoryProvider.overrideWithValue(profile),
          squadAvatarPickerProvider.overrideWithValue(_Picker(avatar)),
        ],
        child: MaterialApp(
          home: ConversationSettingsScreen(
            squadId: 's',
            onManageMembers: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'settings saves private remark/pin independently from shared profile',
    (tester) async {
      final prefs = _Preferences(), profile = _Profile();
      await show(tester, prefs: prefs, profile: profile);
      await tester.enterText(
        find.byKey(const ValueKey('conversation-remark')),
        '只给自己看的名字',
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.tap(find.text('保存个人设置'));
      await tester.pumpAndSettle();
      expect(prefs.remark, '只给自己看的名字');
      expect(prefs.pinned, true);
      expect(profile.name, isNull);
      expect(find.text('个人会话设置已保存'), findsOneWidget);
    },
  );
  testWidgets('member cannot edit shared name/avatar but can set own remark', (
    tester,
  ) async {
    await show(
      tester,
      prefs: _Preferences(),
      profile: _Profile(),
      captain: false,
    );
    expect(find.byKey(const ValueKey('conversation-remark')), findsOneWidget);
    expect(find.byKey(const ValueKey('squad-shared-name')), findsNothing);
    expect(find.text('选择头像'), findsNothing);
    expect(find.text('共享名称和头像由队长修改'), findsOneWidget);
  });
  testWidgets(
    'avatar selection is local until explicit save and cancel preserves it',
    (tester) async {
      final avatar =
          '$squadAvatarPrefix${base64Encode(File('test/features/squad/fixtures/avatar.png').readAsBytesSync())}';
      final profile = _Profile();
      await show(
        tester,
        prefs: _Preferences(),
        profile: profile,
        avatar: avatar,
      );
      await tester.ensureVisible(find.text('选择头像'));
      await tester.tap(find.text('选择头像'));
      await tester.pumpAndSettle();
      expect(profile.avatar, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('squad-shared-name')),
        '新的共享名',
      );
      await tester.ensureVisible(find.text('保存小队资料'));
      await tester.tap(find.text('保存小队资料'));
      await tester.pumpAndSettle();
      expect(profile.name, '新的共享名');
      expect(profile.avatar, avatar);
    },
  );
  testWidgets(
    'failed private save remains editable and does not claim success',
    (tester) async {
      final prefs = _Preferences()..fail = true;
      await show(tester, prefs: prefs, profile: _Profile());
      await tester.tap(find.text('保存个人设置'));
      await tester.pumpAndSettle();
      expect(find.text('请稍后重试'), findsOneWidget);
      expect(find.text('个人会话设置已保存'), findsNothing);
    },
  );
  testWidgets(
    'frequent rail uses aliases, pinned first and excludes unvisited squads',
    (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FrequentSquads(
              squads: [_squad('a'), _squad('b'), _squad('c')],
              preferences: {
                'a': const ConversationPreference(
                  squadId: 'a',
                  remark: '我的常用',
                  recentOpenCount: 9,
                ),
                'b': ConversationPreference(
                  squadId: 'b',
                  pinnedAt: DateTime(2026),
                ),
              },
              onOpen: (s) => opened = s.id,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('frequent-c')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('frequent-b'))).dx,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('frequent-a'))).dx,
        ),
      );
      expect(find.text('我的常用'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('frequent-a')));
      expect(opened, 'a');
    },
  );
}
