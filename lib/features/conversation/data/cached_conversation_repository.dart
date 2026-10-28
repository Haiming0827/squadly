import 'package:fpdart/fpdart.dart';

import '../../../core/error/failures.dart';
import '../../cards/domain/card_composer.dart';
import '../../secure_route/domain/route_models.dart';
import '../domain/conversation_cache.dart';
import '../domain/conversation_photo_repository.dart';
import '../domain/conversation_repository.dart';
import '../domain/photo_head.dart';
import '../domain/timeline_entry.dart';

/// Server authorization always wins. Only transport failures can read the
/// encrypted local copy; denied/not-found/malformed responses never fall back.
final class CachedConversationRepository
    implements ConversationRepository, ConversationPhotoRepository {
  CachedConversationRepository({
    required this.remote,
    required this.cache,
    required this.userId,
    required this.isCurrentAccount,
    this.canReadCache,
  });
  final ConversationRepository remote;
  final ConversationCache cache;
  final String userId;
  final bool Function() isCurrentAccount;
  final bool Function()? canReadCache;
  static const _signedOut = Failure.unauthorized(message: '请重新登录');

  @override
  Future<Either<Failure, PhotoHead>> photoHead(String squadId) =>
      _photoRead((server) => server.photoHead(squadId));

  Future<Either<Failure, T>> _photoRead<T>(
    Future<Either<Failure, T>> Function(ConversationPhotoRepository) request,
  ) async {
    final lease = cache.lease(userId);
    if (!isCurrentAccount() || lease == null) {
      return left(_signedOut);
    }
    final server = remote;
    if (server is! ConversationPhotoRepository) {
      return left(const Failure.server(message: '当前版本暂不支持照片查询'));
    }
    final result = await request(server as ConversationPhotoRepository);
    return isCurrentAccount() && cache.isValid(lease)
        ? result
        : left(_signedOut);
  }

  @override
  Future<Either<Failure, List<TimelineEntry>>> pagePhotos(
    String squadId, {
    TimelineCursor? before,
    int limit = 50,
  }) => _photoRead(
    (server) => server.pagePhotos(squadId, before: before, limit: limit),
  );

  @override
  Future<Either<Failure, TimelineEntry?>> findPhoto({
    required String squadId,
    required String messageId,
  }) => _photoRead(
    (server) => server.findPhoto(squadId: squadId, messageId: messageId),
  );

  Future<Either<Failure, List<TimelineEntry>>> _page(
    String squadId,
    Future<Either<Failure, List<TimelineEntry>>> Function() request, {
    String? planId,
    TimelineCursor? before,
    TimelineCursor? after,
  }) async {
    if (!isCurrentAccount()) return left(_signedOut);
    final lease = cache.lease(userId);
    if (lease == null) return left(_signedOut);
    final result = await request();
    if (!isCurrentAccount() || cache.lease(userId) == null) {
      return left(_signedOut);
    }
    return result.match(
      (failure) async {
        if (failure is! NetworkFailure || !cache.isValid(lease)) {
          return left(failure);
        }
        if (canReadCache?.call() == false) return left(_signedOut);
        try {
          final entries = await cache.page(
            lease,
            squadId,
            planId: planId,
            before: before,
            after: after,
          );
          if (!isCurrentAccount() ||
              !cache.isValid(lease) ||
              canReadCache?.call() == false) {
            return left(_signedOut);
          }
          if (entries.isNotEmpty) {
            return right(entries.map((entry) => entry.asLocalCopy()).toList());
          }
        } catch (_) {
          // A missing key or damaged cache must never expose unverified data.
        }
        return left(failure);
      },
      (entries) async {
        try {
          await cache.save(lease, squadId, entries, planId: planId);
        } catch (_) {
          // Cache failure cannot undo a confirmed server read/send.
        }
        return isCurrentAccount() ? right(entries) : left(_signedOut);
      },
    );
  }

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId, {
    String? planId,
  }) => _page(
    squadId,
    () => remote.loadRecent(squadId, planId: planId),
    planId: planId,
  );
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadBefore(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) => _page(
    squadId,
    () => remote.loadBefore(squadId, cursor, planId: planId),
    planId: planId,
    before: cursor,
  );
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) => _page(
    squadId,
    () => remote.loadAfter(squadId, cursor, planId: planId),
    planId: planId,
    after: cursor,
  );

  Future<Either<Failure, TimelineEntry>> _send(
    String squadId,
    Future<Either<Failure, TimelineEntry>> Function() request, {
    String? planId,
  }) async {
    if (!isCurrentAccount()) return left(_signedOut);
    final lease = cache.lease(userId);
    if (lease == null) return left(_signedOut);
    final result = await request();
    if (!isCurrentAccount()) return left(_signedOut);
    final entry = result.getRight().toNullable();
    if (entry != null) {
      try {
        await cache.save(lease, squadId, [entry], planId: planId);
      } catch (_) {
        /* Best effort. */
      }
    }
    return result;
  }

  @override
  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
    String? planId,
  }) => _send(
    squadId,
    () => remote.sendText(
      squadId: squadId,
      body: body,
      clientNonce: clientNonce,
      replyToEntryId: replyToEntryId,
      planId: planId,
    ),
    planId: planId,
  );
  @override
  Future<Either<Failure, TimelineEntry>> publishCard({
    required String squadId,
    required String cardId,
    required CardSnapshot snapshot,
    required String clientNonce,
    EncryptedRouteBundle? encryptedRoute,
  }) => _send(
    squadId,
    () => remote.publishCard(
      squadId: squadId,
      cardId: cardId,
      snapshot: snapshot,
      clientNonce: clientNonce,
      encryptedRoute: encryptedRoute,
    ),
  );
  @override
  Future<Either<Failure, Map<String, String>>> loadMessageTexts({
    required String squadId,
    required List<String> messageIds,
  }) async {
    if (!isCurrentAccount()) return left(_signedOut);
    final result = await remote.loadMessageTexts(
      squadId: squadId,
      messageIds: messageIds,
    );
    return isCurrentAccount() ? result : left(_signedOut);
  }

  @override
  Stream<void> watchTimeline(String squadId, {String? planId}) =>
      remote.watchTimeline(squadId, planId: planId);
}
