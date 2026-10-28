import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/conversation/domain/cached_conversation_thread.dart';
import 'package:squadly/features/conversation/domain/conversation_cache.dart';
import 'package:squadly/features/conversation/domain/conversation_target.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/conversation/presentation/offline_conversation_controller.dart';

void main() {
  test('expired access never asks cache for a lease or records', () async {
    final cache = _Cache();
    final controller = OfflineConversationController(
      cache: cache,
      userId: 'a',
      canRead: () => false,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(cache.catalogReads, 0);
    expect(controller.state.entries, isEmpty);
  });
  test(
    'opens only a downloaded thread, preserving plan scope and local markers',
    () async {
      final cache = _Cache();
      final controller = OfflineConversationController(
        cache: cache,
        userId: 'a',
        canRead: () => true,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.open(_thread('foreign'));
      expect(cache.pageReads, 0);
      await controller.open(cache.thread);
      expect(cache.requestedPlan, 'p');
      expect(controller.state.entries.single.isLocalCopy, isTrue);
      expect(controller.state.entries.single.text, 'private body');
      controller.back();
      expect(controller.state.entries, isEmpty);
      expect(controller.state.selected, isNull);
    },
  );
  test(
    'expiry while reading cannot display the late decrypted result',
    () async {
      var permitted = true;
      final cache = _Cache()..gate = Completer<List<TimelineEntry>>();
      final controller = OfflineConversationController(
        cache: cache,
        userId: 'a',
        canRead: () => permitted,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final reading = controller.open(cache.thread);
      permitted = false;
      cache.gate!.complete([_entry('late')]);
      await reading;
      expect(controller.state.entries, isEmpty);
    },
  );
  test('returning to catalog supersedes an in-flight thread page', () async {
    final cache = _Cache()..gate = Completer<List<TimelineEntry>>();
    final controller = OfflineConversationController(
      cache: cache,
      userId: 'a',
      canRead: () => true,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final reading = controller.open(cache.thread);
    controller.back();
    cache.gate!.complete([_entry('late')]);
    await reading;
    expect(controller.state.selected, isNull);
    expect(controller.state.entries, isEmpty);
  });
  test('older downloaded pages use the first tuple and deduplicate', () async {
    final cache = _Cache()
      ..entries = [
        for (var i = 5; i < 55; i++) _entry(i.toString().padLeft(3, '0')),
      ];
    final controller = OfflineConversationController(
      cache: cache,
      userId: 'a',
      canRead: () => true,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.open(cache.thread);
    expect(controller.state.hasOlder, isTrue);
    cache.entries = [
      for (var i = 0; i < 6; i++) _entry(i.toString().padLeft(3, '0')),
    ];
    await controller.loadOlder();
    expect(cache.before?.id, '005');
    expect(controller.state.entries, hasLength(55));
    expect(controller.state.entries.first.id, '000');
    expect(controller.state.hasOlder, isFalse);
  });
}

TimelineEntry _entry(String id) => TimelineEntry(
  id: id,
  squadId: 's',
  planId: 'p',
  authorId: 'a',
  authorName: 'A',
  kind: TimelineEntryKind.text,
  text: 'private body',
  clientNonce: id,
  createdAt: DateTime.utc(2026),
);
CachedConversationThread _thread(String planId) => CachedConversationThread(
  target: ConversationTarget(squadId: 's', planId: planId),
  squadName: 'Squad',
  planTitle: 'Plan',
  latestEntry: _entry('one'),
);

class _Cache implements ConversationCache {
  final thread = _thread('p');
  int catalogReads = 0;
  int pageReads = 0;
  String? requestedPlan;
  TimelineCursor? before;
  List<TimelineEntry> entries = [_entry('one')];
  Completer<List<TimelineEntry>>? gate;
  @override
  ConversationCacheLease? lease(String userId) =>
      ConversationCacheLease(userId, 0);
  @override
  bool isValid(ConversationCacheLease lease) => true;
  @override
  Future<List<CachedConversationThread>> threads(
    ConversationCacheLease lease,
  ) async {
    catalogReads++;
    return [thread];
  }

  @override
  Future<List<TimelineEntry>> page(
    ConversationCacheLease lease,
    String squadId, {
    String? planId,
    TimelineCursor? before,
    TimelineCursor? after,
  }) async {
    pageReads++;
    requestedPlan = planId;
    this.before = before;
    return gate == null ? entries : gate!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
