import 'package:flutter_riverpod/legacy.dart';

import '../domain/cached_conversation_thread.dart';
import '../domain/conversation_cache.dart';
import '../domain/timeline_entry.dart';

final class OfflineConversationState {
  OfflineConversationState({
    List<CachedConversationThread> threads = const [],
    List<TimelineEntry> entries = const [],
    this.selected,
    this.isLoading = false,
    this.hasOlder = false,
    this.error,
  }) : threads = List.unmodifiable(threads),
       entries = List.unmodifiable(entries);
  final List<CachedConversationThread> threads;
  final List<TimelineEntry> entries;
  final CachedConversationThread? selected;
  final bool isLoading;
  final bool hasOlder;
  final String? error;
}

/// No remote repository, read receipt writer, or outbox is available here.
final class OfflineConversationController
    extends StateNotifier<OfflineConversationState> {
  OfflineConversationController({
    required this.cache,
    required this.userId,
    required this.canRead,
  }) : _lease = cache?.lease(userId),
       super(OfflineConversationState());
  final ConversationCache? cache;
  final String userId;
  final bool Function() canRead;
  final ConversationCacheLease? _lease;
  int _request = 0;
  bool get _allowed =>
      mounted && canRead() && _lease != null && cache?.isValid(_lease) == true;
  bool _accepts(int request) => _allowed && request == _request;

  Future<void> initialize() async {
    if (!_allowed) return;
    final request = ++_request;
    state = OfflineConversationState(isLoading: true);
    try {
      final threads = await cache!.threads(_lease!);
      if (_accepts(request)) state = OfflineConversationState(threads: threads);
    } catch (_) {
      if (_accepts(request)) {
        state = OfflineConversationState(error: '本机记录暂时无法读取，请重试');
      }
    }
  }

  Future<void> open(CachedConversationThread thread) async {
    if (!_allowed ||
        !state.threads.any((item) => item.target == thread.target)) {
      return;
    }
    final request = ++_request;
    state = OfflineConversationState(
      threads: state.threads,
      selected: thread,
      isLoading: true,
    );
    try {
      final entries = await cache!.page(
        _lease!,
        thread.target.squadId,
        planId: thread.target.planId,
      );
      if (_accepts(request)) {
        state = OfflineConversationState(
          threads: state.threads,
          selected: thread,
          entries: entries.map((entry) => entry.asLocalCopy()).toList(),
          hasOlder: entries.length == 50,
        );
      }
    } catch (_) {
      if (_accepts(request)) {
        state = OfflineConversationState(
          threads: state.threads,
          selected: thread,
          error: '本机记录暂时无法读取，请重试',
        );
      }
    }
  }

  Future<void> loadOlder() async {
    final selected = state.selected;
    if (!_allowed ||
        selected == null ||
        !state.hasOlder ||
        state.isLoading ||
        state.entries.isEmpty) {
      return;
    }
    final request = ++_request;
    final entries = state.entries;
    state = OfflineConversationState(
      threads: state.threads,
      selected: selected,
      entries: entries,
      isLoading: true,
      hasOlder: true,
    );
    try {
      final older = await cache!.page(
        _lease!,
        selected.target.squadId,
        planId: selected.target.planId,
        before: entries.first.cursor,
      );
      if (!_accepts(request)) return;
      final merged = <String, TimelineEntry>{
        for (final entry in [...older, ...entries]) entry.id: entry,
      };
      final ordered = merged.values.toList()
        ..sort((a, b) {
          final byTime = a.createdAt.compareTo(b.createdAt);
          return byTime == 0 ? a.id.compareTo(b.id) : byTime;
        });
      state = OfflineConversationState(
        threads: state.threads,
        selected: selected,
        entries: ordered.map((entry) => entry.asLocalCopy()).toList(),
        hasOlder: older.length == 50,
      );
    } catch (_) {
      if (_accepts(request)) {
        state = OfflineConversationState(
          threads: state.threads,
          selected: selected,
          entries: entries,
          hasOlder: true,
          error: '较早记录暂时无法读取，请重试',
        );
      }
    }
  }

  void back() {
    if (!mounted) return;
    _request++;
    state = OfflineConversationState(threads: state.threads);
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }
}
