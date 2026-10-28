import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/app.dart';
import 'package:squadly/app/providers/conversation_cache_provider.dart';
import 'package:squadly/app/providers/conversation_runtime_providers.dart';
import 'package:squadly/app/providers/domain_repository_providers.dart';
import 'package:squadly/app/providers/offline_access_provider.dart';
import 'package:squadly/app/router.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/auth/domain/offline_session.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/conversation/data/conversation_cache_database.dart';
import 'package:squadly/features/conversation/data/drift_conversation_cache.dart';
import 'package:squadly/features/conversation/data/outbox_key_vault.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';

void main() {
  testWidgets(
    'cold-start login can open downloaded plans read-only, then expiry hides them',
    (tester) async {
      final harness = await _Harness.create();
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const SquadlyApp(),
          ),
        );
        harness.source.events.add(harness.session('a'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('本机聊天记录'));
        await tester.tap(find.text('本机聊天记录'));
        await tester.pumpAndSettle();
        expect(find.text('私密计划 A'), findsOneWidget);
        expect(find.text('秘密正文 B'), findsNothing);
        await tester.tap(find.text('私密计划 A'));
        await tester.pumpAndSettle();
        expect(find.text('秘密正文 A'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.byTooltip('发送消息'), findsNothing);
        expect(find.text('只读', findRichText: true), findsNothing);
        expect(find.textContaining('本机副本 · 只读'), findsOneWidget);
        harness.now = harness.now.add(const Duration(hours: 2));
        harness.container.read(offlineAccessProvider.notifier).checkExpiry();
        await tester.pumpAndSettle();
        expect(find.text('秘密正文 A'), findsNothing);
        expect(find.text('私密计划 A'), findsNothing);
        expect(find.text('登录已过期'), findsOneWidget);
        expect(
          (await harness.cache.page(
            harness.cache.lease('a')!,
            's',
            planId: 'p',
          )).single.text,
          '秘密正文 A',
        );
        await tester.tap(find.text('前往登录'));
        await tester.pumpAndSettle();
        expect(find.text('邮箱登录'), findsOneWidget);
        expect(
          (await harness.cache.page(
            harness.cache.lease('a')!,
            's',
            planId: 'p',
          )).single.text,
          '秘密正文 A',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await harness.close();
      }
    },
  );

  testWidgets(
    'SDK account switch replaces displayed records and clears original account',
    (tester) async {
      final harness = await _Harness.create();
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const SquadlyApp(),
          ),
        );
        harness.source.events.add(harness.session('a'));
        await tester.pumpAndSettle();
        harness.container.read(routerProvider).go('/offline');
        await tester.pumpAndSettle();
        await tester.tap(find.text('私密计划 A'));
        await tester.pumpAndSettle();
        harness.cache.resumeUser('b');
        final bLease = harness.cache.lease('b')!;
        await harness.cache.save(bLease, 's', [
          TimelineEntry(
            id: 'message-b',
            squadId: 's',
            planId: 'p',
            authorId: 'b',
            authorName: 'B',
            kind: TimelineEntryKind.text,
            text: '秘密正文 B',
            clientNonce: 'b',
            createdAt: DateTime.utc(2026),
          ),
        ], planId: 'p');
        await harness.cache.rememberThread(
          bLease,
          's',
          '测试小队',
          planId: 'p',
          planTitle: '私密计划 B',
        );
        harness.source.events.add(harness.session('b'));
        await tester.pumpAndSettle();
        expect(find.text('秘密正文 A'), findsNothing);
        expect(find.text('私密计划 A'), findsNothing);
        expect(find.text('私密计划 B'), findsOneWidget);
        await tester.tap(find.text('私密计划 B'));
        await tester.pumpAndSettle();
        expect(find.text('秘密正文 B'), findsOneWidget);
        expect(
          await harness.db.pageRows(userId: 'a', squadId: 's', planId: 'p'),
          isEmpty,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await harness.close();
      }
    },
  );

  testWidgets(
    'missing/expired sessions cannot reveal catalog on direct route',
    (tester) async {
      final harness = await _Harness.create();
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const SquadlyApp(),
          ),
        );
        harness.container.read(routerProvider).go('/offline');
        harness.source.events.add(
          OfflineSession(
            userId: 'a',
            expiresAt: harness.now.subtract(const Duration(seconds: 1)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('登录已过期'), findsOneWidget);
        expect(find.text('私密计划 A'), findsNothing);
        expect(harness.container.read(authNotifierProvider).value, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await harness.close();
      }
    },
  );
}

class _Harness {
  _Harness(this.db, this.cache, this.source);
  final ConversationCacheDatabase db;
  final DriftConversationCache cache;
  final _Source source;
  late ProviderContainer container;
  DateTime now = DateTime.now();
  OfflineSession session(String id) =>
      OfflineSession(userId: id, expiresAt: now.add(const Duration(hours: 1)));
  static Future<_Harness> create() async {
    final db = ConversationCacheDatabase(NativeDatabase.memory());
    final cache = DriftConversationCache(database: db, vault: _Vault());
    for (final id in ['a', 'b']) {
      final lease = cache.lease(id)!;
      final upper = id.toUpperCase();
      await cache.save(lease, 's', [
        TimelineEntry(
          id: 'message-$id',
          squadId: 's',
          planId: 'p',
          authorId: id,
          authorName: upper,
          kind: TimelineEntryKind.text,
          text: '秘密正文 $upper',
          clientNonce: id,
          createdAt: DateTime.utc(2026),
        ),
      ], planId: 'p');
      await cache.rememberThread(
        lease,
        's',
        '测试小队',
        planId: 'p',
        planTitle: '私密计划 $upper',
      );
    }
    final harness = _Harness(db, cache, _Source());
    harness.container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_SignedOut.new),
        conversationCacheProvider.overrideWithValue(cache),
        offlineAccessProvider.overrideWith(
          (ref) => OfflineAccessController(
            source: harness.source,
            clock: () => harness.now,
          ),
        ),
        conversationRepositoryProvider.overrideWith(
          (ref) => throw StateError(
            'Offline view must not initialize remote messaging',
          ),
        ),
        conversationOutboxProvider.overrideWith(
          (ref) =>
              throw StateError('Offline view must not retry pending sends'),
        ),
      ],
    );
    return harness;
  }

  Future<void> close() async {
    container.dispose();
    await source.events.close();
    await db.close();
  }
}

class _SignedOut extends AuthNotifier {
  @override
  AsyncValue<User?> build() => const AsyncData(null);
}

class _Source implements OfflineSessionSource {
  final events = StreamController<OfflineSession?>.broadcast(sync: true);
  @override
  Stream<OfflineSession?> watch() => events.stream;
}

class _Vault implements OutboxKeyVault {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
