import 'cached_conversation_thread.dart';
import 'timeline_entry.dart';

final class ConversationCacheLease {
  const ConversationCacheLease(this.userId, this.generation);
  final String userId;
  final int generation;
}

/// Removes stale account copies left by an interrupted account switch. It
/// never touches the separately encrypted pending-send queue.
abstract interface class ConversationCacheAccountCleanup {
  Future<void> clearOtherUsers(String activeUserId);
}

/// Downloaded, sent entries only. Pending sends have a separate lifetime/store.
abstract interface class ConversationCache {
  ConversationCacheLease? lease(String userId);
  bool isValid(ConversationCacheLease lease);
  void resumeUser(String userId);
  Future<void> clearUser(String userId, {bool suspend = false});
  Future<void> rememberThread(
    ConversationCacheLease lease,
    String squadId,
    String squadName, {
    String? planId,
    String? planTitle,
  });
  Future<List<CachedConversationThread>> threads(ConversationCacheLease lease);
  Future<void> save(
    ConversationCacheLease lease,
    String squadId,
    List<TimelineEntry> entries, {
    String? planId,
  });
  Future<List<TimelineEntry>> page(
    ConversationCacheLease lease,
    String squadId, {
    String? planId,
    TimelineCursor? before,
    TimelineCursor? after,
  });
}
