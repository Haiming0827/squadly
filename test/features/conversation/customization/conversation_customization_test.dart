import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squadly/app/demo/demo_conversation_customization.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/conversation/data/cloudbase_conversation_customization.dart';
import 'package:squadly/features/conversation/domain/conversation_preference.dart';
import 'package:squadly/features/conversation/presentation/conversation_list_controls.dart';
import 'package:squadly/features/squad/data/cloudbase_squad_profile_repository.dart';
import 'package:squadly/features/squad/domain/squad_avatar_format.dart';

void main() {
  test('filters distinguish squad pins from independent plan discussions', () {
    expect(
      matchesConversationActivity(
        ConversationActivityFilter.pinned,
        true,
        isPinned: true,
      ),
      true,
    );
    expect(
      matchesConversationActivity(
        ConversationActivityFilter.pinned,
        true,
        isPinned: true,
        isPlan: true,
      ),
      false,
    );
    expect(
      matchesConversationActivity(
        ConversationActivityFilter.plans,
        false,
        isPlan: true,
      ),
      true,
    );
    expect(
      matchesConversationActivity(
        ConversationActivityFilter.squads,
        true,
        isPlan: true,
      ),
      false,
    );
    expect(
      matchesConversationActivity(
        ConversationActivityFilter.withoutMessages,
        false,
      ),
      true,
    );
    expect(
      matchesConversationActivity(
        ConversationActivityFilter.withMessages,
        false,
      ),
      false,
    );
  });

  test('pinned then recent frequency then recency sorts deterministically', () {
    final values = [
      const ConversationPreference(squadId: 'old', recentOpenCount: 0),
      ConversationPreference(
        squadId: 'frequent',
        recentOpenCount: 8,
        lastOpenedAt: DateTime(2026, 11, 1),
      ),
      ConversationPreference(
        squadId: 'recent',
        recentOpenCount: 2,
        lastOpenedAt: DateTime(2026, 11, 3),
      ),
      ConversationPreference(squadId: 'pin', pinnedAt: DateTime(2026, 11, 2)),
    ]..sort(compareFrequentConversations);
    expect(values.map((p) => p.squadId), ['pin', 'frequent', 'recent', 'old']);
    expect(values.first.displayName('原名'), '原名');
    expect(values.first.copyWith(remark: '自己的名字').displayName('原名'), '自己的名字');
  });
  test('avatar accepts bounded 96px PNG and rejects urls, other sizes and malformed bytes', () {
    final png = File('test/features/squad/fixtures/avatar.png')
        .readAsBytesSync();
    expect(decodeSquadAvatar('$squadAvatarPrefix${base64Encode(png)}'), png);
    expect(decodeSquadAvatar('https://example.com/photo'), isNull);
    expect(decodeSquadAvatar('${squadAvatarPrefix}not-base64'), isNull);
    expect(decodeSquadAvatar('$squadAvatarPrefix${'a' * 65540}'), isNull);
    png[19] = 95;
    expect(decodeSquadAvatar('$squadAvatarPrefix${base64Encode(png)}'), isNull);
  });
  test('CloudBase preference transport never submits an owner id', () async {
    final requests = <http.Request>[];
    final client = PostgrestClient(
      'https://example.com/rest',
      httpClient: MockClient((r) async {
        requests.add(r);
        final body = r.url.path.endsWith('get_conversation_preferences')
            ? [
                {
                  'squad_id': 's',
                  'remark': '自己的备注',
                  'pinned_at': null,
                  'last_opened_at': '2026-11-03T01:00:00Z',
                  'recent_open_count': 4,
                },
              ]
            : {'saved': true};
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    addTearDown(client.dispose);
    final repo = CloudBaseConversationCustomization(client);
    final result = await repo.load();
    expect(result.getRight().toNullable()!.single.remark, '自己的备注');
    await repo.save(squadId: 's', remark: '  新备注 ', pinned: true);
    expect(jsonDecode(requests.last.body), {
      'p_squad_id': 's',
      'p_remark': '新备注',
      'p_pinned': true,
    });
    await repo.recordOpen('s');
    expect(jsonDecode(requests.last.body), {'p_squad_id': 's'});
    final count = requests.length;
    expect(
      (await repo.save(squadId: 's', remark: '字' * 41, pinned: false)).isLeft(),
      true,
    );
    expect(requests.length, count);
  });
  test('profile repository preserves permissions and validates avatars before transport', () async {
    var calls = 0;
    final client = PostgrestClient(
      'https://example.com/rest',
      httpClient: MockClient((r) async {
        calls++;
        return http.Response(
          '{"error":"forbidden"}',
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    addTearDown(client.dispose);
    final repo = CloudBaseSquadProfileRepository(client);
    expect(
      (await repo.save(
        squadId: 's',
        name: '新名字',
        description: '',
        avatar: null,
      )).getLeft().toNullable(),
      isA<PermissionDeniedFailure>(),
    );
    expect(
      (await repo.save(
        squadId: 's',
        name: '新名字',
        description: '',
        avatar: 'https://example.com',
      )).getLeft().toNullable(),
      isA<ValidationFailure>(),
    );
    expect(calls, 1);
  });
  test('malformed preference responses are safe failures', () async {
    final client = PostgrestClient(
      'https://example.com/rest',
      httpClient: MockClient(
        (r) async => http.Response(
          '[{}]',
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        ),
      ),
    );
    addTearDown(client.dispose);
    expect(
      (await CloudBaseConversationCustomization(client).load()).isLeft(),
      true,
    );
  });
  test(
    'demo preferences are owner scoped, persistent and serialized',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = DemoAppStore()
        ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
      addTearDown(store.dispose);
      final user = store.getCurrentUser()!;
      final repo = DemoConversationCustomization(store, user.id);
      final squad = store.snapshot.mySquads.first;
      await Future.wait([
        repo.recordOpen(squad.id),
        repo.save(squadId: squad.id, remark: '我的备注', pinned: true),
      ]);
      final fresh = DemoConversationCustomization(store, user.id);
      final value = (await fresh.load()).getRight().toNullable()!.firstWhere(
        (p) => p.squadId == squad.id,
      );
      expect(value.remark, '我的备注');
      expect(value.isPinned, true);
      expect(value.recentOpenCount, 1);
      final foreign = DemoConversationCustomization(store, 'another-account');
      expect((await foreign.load()).getRight().toNullable(), isEmpty);
      expect(
        (await foreign.save(
          squadId: squad.id,
          remark: 'forged',
          pinned: false,
        )).isLeft(),
        true,
      );
    },
  );
  test('demo captain check cannot be bypassed via profile adapter', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    addTearDown(store.dispose);
    final repo = DemoSquadProfileRepository(store);
    final squad = store.createSquad(name: '我的小队');
    expect(
      (await repo.save(
        squadId: squad.id,
        name: '新名字',
        description: '简介',
        avatar: null,
      )).isRight(),
      true,
    );
    expect(
      store.snapshot.squads.firstWhere((s) => s.id == squad.id).name,
      '新名字',
    );
    expect(
      (await repo.save(
        squadId: 'unknown',
        name: '新名字',
        description: '',
        avatar: null,
      )).getLeft().toNullable(),
      isA<PermissionDeniedFailure>(),
    );
  });
}
