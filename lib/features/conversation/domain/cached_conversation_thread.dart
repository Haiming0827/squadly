import 'conversation_target.dart';
import 'timeline_entry.dart';

/// Labels and preview for previously downloaded records, not live membership.
final class CachedConversationThread {
  const CachedConversationThread({
    required this.target,
    required this.squadName,
    required this.latestEntry,
    this.planTitle,
  });
  final ConversationTarget target;
  final String squadName;
  final String? planTitle;
  final TimelineEntry latestEntry;
  String get title => target.isPlanDiscussion ? planTitle ?? '计划讨论' : squadName;
}
