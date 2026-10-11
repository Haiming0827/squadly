import 'dart:collection';

import '../../cards/domain/card_composer.dart';

enum TimelineEntryKind { text, card }

/// A cursor combines the server timestamp with its stable ID, so entries
/// created at the same instant are not skipped while paging.
final class TimelineCursor {
  const TimelineCursor({required this.createdAt, required this.id});

  final DateTime createdAt;
  final String id;
}

/// A message visible in one squad's conversation timeline.
final class TimelineEntry {
  TimelineEntry({
    required this.id,
    required this.squadId,
    required this.authorId,
    required this.authorName,
    required this.kind,
    required this.clientNonce,
    required this.createdAt,
    this.text,
    this.cardId,
    this.cardSnapshot,
    this.replyToEntryId,
  }) {
    if (kind == TimelineEntryKind.text &&
        (text == null || text!.trim().isEmpty || cardId != null)) {
      throw ArgumentError('Text entries need text and cannot reference a card');
    }
    if (kind == TimelineEntryKind.card && (cardId == null || text != null)) {
      throw ArgumentError(
        'Card entries need a card ID and cannot contain text',
      );
    }
  }

  final String id;
  final String squadId;
  final String authorId;
  final String authorName;
  final TimelineEntryKind kind;
  final String? text;
  final String? cardId;
  final CardSnapshot? cardSnapshot;
  final String? replyToEntryId;
  final String clientNonce;
  final DateTime createdAt;

  TimelineCursor get cursor => TimelineCursor(createdAt: createdAt, id: id);
}

/// Immutable public state exposed by [ConversationController].
final class ConversationState {
  ConversationState({
    required List<TimelineEntry> entries,
    this.isLoading = false,
    this.error,
    this.pendingCount = 0,
  }) : entries = UnmodifiableListView(entries);

  final List<TimelineEntry> entries;
  final bool isLoading;
  final Object? error;
  final int pendingCount;
}
