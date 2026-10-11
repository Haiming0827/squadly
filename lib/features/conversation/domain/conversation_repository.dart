import 'package:fpdart/fpdart.dart';

import '../../../core/error/failures.dart';
import '../../cards/domain/card_composer.dart';
import '../../secure_route/domain/route_models.dart';
import 'timeline_entry.dart';

/// The seam shared by in-memory tests and the remote Supabase adapter.
abstract interface class ConversationRepository {
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(String squadId);

  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor,
  );

  Future<Either<Failure, List<TimelineEntry>>> loadBefore(
    String squadId,
    TimelineCursor cursor,
  );

  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
  });

  Future<Either<Failure, TimelineEntry>> publishCard({
    required String squadId,
    required String cardId,
    required CardSnapshot snapshot,
    required String clientNonce,
    EncryptedRouteBundle? encryptedRoute,
  });

  /// Resolve an approved conversation card's selected message IDs for local
  /// rendering. The server still enforces squad membership through RLS.
  Future<Either<Failure, Map<String, String>>> loadMessageTexts({
    required String squadId,
    required List<String> messageIds,
  });

  /// Events are hints. The repository's paged results remain the source of
  /// truth, including after disconnects and app restarts.
  Stream<void> watchTimeline(String squadId);
}
