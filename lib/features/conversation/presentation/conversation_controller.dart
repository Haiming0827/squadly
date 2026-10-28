import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/failures.dart';
import '../../cards/domain/card_composer.dart';
import '../../photos/domain/photo.dart';
import '../../photos/domain/photo_repository.dart';
import '../../photos/domain/photo_submission.dart';
import '../../photos/domain/prepare_squad_photo.dart';
import '../../secure_route/domain/route_models.dart';
import '../domain/conversation_outbox.dart';
import '../domain/conversation_repository.dart';
import '../domain/pending_operation.dart';
import '../domain/timeline_entry.dart';

/// Coordinates paged server truth with realtime refresh hints for one squad.
final class ConversationController extends StateNotifier<ConversationState> {
  ConversationController({
    required this.repository,
    required this.outbox,
    required this.squadId,
    required this.currentUserId,
    this.planId,
    this.onlineEvents,
    this.photos,
    this.canPublishPhoto,
  }) : super(ConversationState(entries: const []));

  final ConversationRepository repository;
  final ConversationOutbox outbox;
  final String squadId;
  final String currentUserId;
  final String? planId;
  final Stream<bool>? onlineEvents;
  final PhotoRepository? photos;
  final PhotoTargetAccess? canPublishPhoto;

  StreamSubscription<void>? _subscription;
  StreamSubscription<bool>? _onlineSubscription;
  bool _disposed = false;
  bool _refreshing = false;
  bool _refreshRequested = false;
  bool _draining = false;
  final _inFlightNonces = <String>{};
  final _photoConfirming = <String>{};
  static const _pageSize = 50;
  static const _closedFailure = Failure.validation(message: '会话已关闭，请重新进入后发送');

  void _emit({
    List<TimelineEntry>? entries,
    bool isLoading = false,
    Object? error,
    int? pendingCount,
    bool clearError = false,
  }) {
    if (_disposed) return;
    state = ConversationState(
      entries: entries ?? state.entries,
      isLoading: isLoading,
      error: clearError ? null : error ?? state.error,
      pendingCount: pendingCount ?? state.pendingCount,
    );
  }

  Future<void> initialize() async {
    if (_disposed) return;
    _emit(isLoading: true, clearError: true);
    _onlineSubscription ??= onlineEvents?.listen((isOnline) {
      if (isOnline) unawaited(refresh());
    });
    _subscription ??= repository.watchTimeline(squadId, planId: planId).listen((
      _,
    ) {
      unawaited(refresh());
    });
    final result = await repository.loadRecent(squadId, planId: planId);
    if (_disposed) return;
    result.match(
      (failure) => _emit(error: failure),
      (entries) => _emit(
        entries: _orderedUnique([...state.entries, ...entries]),
        clearError: true,
      ),
    );
    await retryPending();
  }

  Future<Either<Failure, TimelineEntry>> sendText(
    String body, {
    String? replyToEntryId,
  }) async {
    if (_disposed) return left(_closedFailure);
    final normalized = body.trim();
    if (normalized.isEmpty) {
      return left(const Failure.validation(message: '消息不能为空'));
    }
    if (currentUserId.isEmpty) {
      return left(const Failure.unauthorized(message: '请先登录'));
    }
    if (replyToEntryId != null &&
        !state.entries.any(
          (entry) =>
              entry.id == replyToEntryId &&
              entry.squadId == squadId &&
              entry.planId == planId,
        )) {
      return left(const Failure.validation(message: '回复目标已不可见，请刷新会话'));
    }
    try {
      final pending = await outbox.listFor(
        userId: currentUserId,
        squadId: squadId,
        planId: planId,
      );
      if (_disposed) return left(_closedFailure);
      final previous = pending
          .whereType<PendingTextOperation>()
          .where(
            (entry) =>
                entry.body == normalized &&
                entry.replyToEntryId == replyToEntryId,
          )
          .lastOrNull;
      final attempt =
          previous ??
          PendingConversationOperation.text(
            userId: currentUserId,
            squadId: squadId,
            clientNonce: const Uuid().v4(),
            createdAt: DateTime.now().toUtc(),
            body: normalized,
            planId: planId,
            replyToEntryId: replyToEntryId,
          );
      if (previous == null) await outbox.put(attempt);
      _emit(pendingCount: pending.length + (previous == null ? 1 : 0));
      return await _sendPending(attempt);
    } catch (_) {
      const failure = Failure.server(message: '本机待发消息不可用，请检查设备存储');
      _emit(error: failure);
      return left(failure);
    }
  }

  Future<Either<Failure, TimelineEntry>> publishCard({
    required String cardId,
    required CardSnapshot snapshot,
    EncryptedRouteBundle? encryptedRoute,
  }) async {
    if (_disposed) return left(_closedFailure);
    if (planId != null) {
      return left(const Failure.validation(message: '计划讨论暂不支持发布卡片，请在小队会话中分享'));
    }
    if (snapshot.hasEncryptedRoute != (encryptedRoute != null)) {
      return left(const Failure.validation(message: '卡片路线加密状态不一致'));
    }
    if (currentUserId.isEmpty) {
      return left(const Failure.unauthorized(message: '请先登录'));
    }
    try {
      final pending = await outbox.listFor(
        userId: currentUserId,
        squadId: squadId,
        planId: planId,
      );
      if (_disposed) return left(_closedFailure);
      final previous = pending
          .whereType<PendingCardOperation>()
          .where((entry) => entry.cardId == cardId)
          .firstOrNull;
      if (previous != null &&
          !_sameCardRequest(previous, snapshot, encryptedRoute)) {
        return left(const Failure.validation(message: '卡片内容已改变，请重新预览'));
      }
      final attempt =
          previous ??
          PendingConversationOperation.card(
            userId: currentUserId,
            squadId: squadId,
            clientNonce: const Uuid().v4(),
            createdAt: DateTime.now().toUtc(),
            cardId: cardId,
            planId: planId,
            snapshot: snapshot,
            encryptedRoute: encryptedRoute,
          );
      if (previous == null) await outbox.put(attempt);
      _emit(pendingCount: pending.length + (previous == null ? 1 : 0));
      return await _sendPending(attempt);
    } catch (_) {
      const failure = Failure.server(message: '本机待发卡片不可用，请检查设备存储');
      _emit(error: failure);
      return left(failure);
    }
  }

  Future<PhotoSubmissionResult> publishPhoto(PhotoDraft draft) async {
    if (_disposed) return const PhotoSubmissionResult.rejected(_closedFailure);
    if (planId != null ||
        draft.target.userId != currentUserId ||
        draft.target.squadId != squadId ||
        currentUserId.isEmpty ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(draft.clientNonce)) {
      return const PhotoSubmissionResult.rejected(
        Failure.validation(message: '照片账号或小队不匹配，请重新预览'),
      );
    }
    if (!_photoConfirming.add(draft.clientNonce)) {
      return const PhotoSubmissionResult.unconfirmed(
        Failure.validation(message: '这张照片正在处理，请稍候'),
      );
    }
    var persisted = false;
    var writing = false;
    try {
      final pending = await outbox.listFor(
        userId: currentUserId,
        squadId: squadId,
      );
      if (_disposed) {
        return const PhotoSubmissionResult.rejected(_closedFailure);
      }
      final previous = pending
          .where((p) => p.clientNonce == draft.clientNonce)
          .firstOrNull;
      if (previous != null &&
          (previous is! PendingPhotoOperation ||
              !sameConfirmedPhoto(previous.draft, draft))) {
        return const PhotoSubmissionResult.rejected(
          Failure.validation(message: '已确认照片不能替换，请使用原照片重试'),
        );
      }
      final operation =
          previous as PendingPhotoOperation? ??
          PendingPhotoOperation(
            userId: currentUserId,
            squadId: squadId,
            squadName: draft.target.squadName,
            clientNonce: draft.clientNonce,
            createdAt: draft.preparedAt,
            image: draft.image,
            replyToEntryId: draft.target.replyToMessageId,
          );
      if (previous == null) {
        writing = true;
        await outbox.put(operation);
      }
      persisted = true;
      if (_disposed) return const PhotoSubmissionResult.pending(_closedFailure);
      await _syncPendingCount();
      final result = await _deliverPhoto(operation);
      return result.match<PhotoSubmissionResult>(
        PhotoSubmissionResult.pending,
        (_) => const PhotoSubmissionResult.sent(),
      );
    } catch (_) {
      const failure = Failure.server(message: '照片本机保存状态未确认，请使用原照片重试');
      _emit(error: failure);
      return persisted
          ? const PhotoSubmissionResult.pending(failure)
          : writing
          ? const PhotoSubmissionResult.unconfirmed(failure)
          : const PhotoSubmissionResult.rejected(failure);
    } finally {
      _photoConfirming.remove(draft.clientNonce);
    }
  }

  Future<Either<Failure, PublishedPhoto>> _deliverPhoto(
    PendingPhotoOperation operation,
  ) async {
    if (_disposed ||
        operation.userId != currentUserId ||
        operation.squadId != squadId ||
        planId != null) {
      return left(_closedFailure);
    }
    if (!_inFlightNonces.add(operation.clientNonce)) {
      return left(const Failure.validation(message: '这张照片正在发送，请稍候'));
    }
    try {
      final remote = photos;
      final access = canPublishPhoto;
      if (remote == null || access == null) {
        return left(const Failure.server(message: '照片服务暂不可用，已保留待发'));
      }
      final allowed = await access(operation.draft.target);
      if (_disposed) return left(_closedFailure);
      if (!allowed) {
        const failure = Failure.permissionDenied(message: '当前无法确认原小队权限，照片仍在待发');
        _emit(error: failure);
        return left(failure);
      }
      final result = await remote.publish(operation.draft);
      if (_disposed) return result;
      final published = result.getRight().toNullable();
      if (published == null) {
        result.match((failure) => _emit(error: failure), (_) {});
        return result;
      }
      if (published.squadId != operation.squadId ||
          published.authorId != operation.userId ||
          published.clientNonce != operation.clientNonce ||
          published.replyToMessageId != operation.replyToEntryId) {
        const failure = Failure.server(message: '照片送达身份未确认，已保留原请求');
        _emit(error: failure);
        return left(failure);
      }
      try {
        await outbox.remove(
          userId: operation.userId,
          squadId: operation.squadId,
          clientNonce: operation.clientNonce,
        );
        await _syncPendingCount();
      } catch (_) {
        _emit(error: const Failure.server(message: '照片已送达，本机待发状态仍需同步'));
      }
      // Re-fetch the canonical projection after server re-encoding. A failed
      // read cannot reverse the authoritative publish acknowledgement.
      unawaited(reloadRecent());
      return result;
    } catch (_) {
      const failure = Failure.network(message: '照片发送未确认，已保留原请求');
      _emit(error: failure);
      return left(failure);
    } finally {
      _inFlightNonces.remove(operation.clientNonce);
    }
  }

  Future<Either<Failure, TimelineEntry>> _sendPending(
    PendingConversationOperation operation,
  ) async {
    // Persisted attempts retain their original account scope. A controller
    // disposed during local IO must not resume sending in a later session.
    if (_disposed) return left(_closedFailure);
    if (!_inFlightNonces.add(operation.clientNonce)) {
      return left(const Failure.validation(message: '消息正在发送，请稍候'));
    }
    try {
      final result = switch (operation) {
        PendingPhotoOperation() => left<Failure, TimelineEntry>(
          const Failure.validation(message: '照片需要独立媒体发送流程'),
        ),
        PendingTextOperation(:final body, :final replyToEntryId) =>
          await repository.sendText(
            squadId: squadId,
            body: body,
            clientNonce: operation.clientNonce,
            replyToEntryId: replyToEntryId,
            planId: operation.planId,
          ),
        PendingCardOperation(
          :final cardId,
          :final snapshot,
          :final encryptedRoute,
        ) =>
          await repository.publishCard(
            squadId: squadId,
            cardId: cardId,
            snapshot: snapshot,
            clientNonce: operation.clientNonce,
            encryptedRoute: encryptedRoute,
          ),
      };
      if (_disposed) return result;
      await result.match<Future<void>>(
        (failure) async => _emit(error: failure),
        (entry) => _acknowledge(operation, entry),
      );
      return result;
    } catch (_) {
      const failure = Failure.network(message: '发送未确认，稍后会用同一请求重试');
      _emit(error: failure);
      return left(failure);
    } finally {
      _inFlightNonces.remove(operation.clientNonce);
    }
  }

  Future<void> _acknowledge(
    PendingConversationOperation operation,
    TimelineEntry entry,
  ) async {
    try {
      await outbox.remove(
        userId: operation.userId,
        squadId: operation.squadId,
        clientNonce: operation.clientNonce,
        planId: operation.planId,
      );
      if (_disposed) return;
      await _syncPendingCount();
      _emit(
        entries: _orderedUnique([...state.entries, entry]),
        clearError: true,
      );
    } catch (_) {
      // The server ack is authoritative. A later retry with the same nonce
      // can safely clean up the local entry without inserting another row.
      if (_disposed) return;
      _emit(
        entries: _orderedUnique([...state.entries, entry]),
        error: const Failure.server(message: '消息已送达，本机待发状态仍需同步'),
      );
    }
  }

  static bool _sameCardRequest(
    PendingCardOperation previous,
    CardSnapshot snapshot,
    EncryptedRouteBundle? encryptedRoute,
  ) =>
      jsonEncode([
        previous.snapshot.kind.name,
        previous.snapshot.templateId,
        previous.snapshot.templateVersion,
        previous.snapshot.hasEncryptedRoute,
        previous.snapshot.payload,
        previous.encryptedRoute?.toJson(),
      ]) ==
      jsonEncode([
        snapshot.kind.name,
        snapshot.templateId,
        snapshot.templateVersion,
        snapshot.hasEncryptedRoute,
        snapshot.payload,
        encryptedRoute?.toJson(),
      ]);

  /// Replays only attempts belonging to this signed-in account and squad.
  /// A repeated server ack is safe because the original nonce is retained.
  Future<void> retryPending() async {
    if (_disposed || currentUserId.isEmpty || _draining) return;
    _draining = true;
    try {
      final pending = await outbox.listFor(
        userId: currentUserId,
        squadId: squadId,
        planId: planId,
      );
      _emit(pendingCount: pending.length);
      for (final operation in pending) {
        if (_disposed) break;
        if (_inFlightNonces.contains(operation.clientNonce)) continue;
        if (operation is PendingPhotoOperation) {
          await _deliverPhoto(operation);
        } else {
          await _sendPending(operation);
        }
      }
      await _syncPendingCount();
    } catch (_) {
      _emit(error: const Failure.server(message: '本机待发队列无法读取，请检查设备存储'));
    } finally {
      _draining = false;
    }
  }

  Future<void> _syncPendingCount() async {
    if (_disposed) return;
    final pending = await outbox.listFor(
      userId: currentUserId,
      squadId: squadId,
      planId: planId,
    );
    if (!_disposed) _emit(pendingCount: pending.length);
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (_refreshing) {
      _refreshRequested = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshRequested = false;
        while (!_disposed) {
          final entries = state.entries;
          final result = entries.isEmpty
              ? await repository.loadRecent(squadId, planId: planId)
              : await repository.loadAfter(
                  squadId,
                  entries.last.cursor,
                  planId: planId,
                );
          if (_disposed) return;
          final page = result.match<List<TimelineEntry>?>(
            (failure) {
              _emit(error: failure);
              return null;
            },
            (newEntries) {
              _emit(
                entries: _orderedUnique([...state.entries, ...newEntries]),
                clearError: true,
              );
              return newEntries;
            },
          );
          if (page == null || page.length < _pageSize || entries.isEmpty) break;
          final previousCursor = entries.last.cursor;
          final nextCursor = page.last.cursor;
          if (nextCursor.createdAt.isBefore(previousCursor.createdAt) ||
              (nextCursor.createdAt.isAtSameMomentAs(
                    previousCursor.createdAt,
                  ) &&
                  nextCursor.id.compareTo(previousCursor.id) <= 0)) {
            break;
          }
        }
        await retryPending();
      } while (_refreshRequested && !_disposed);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> loadEarlier() async {
    if (_disposed || state.entries.isEmpty) return;
    final result = await repository.loadBefore(
      squadId,
      state.entries.first.cursor,
      planId: planId,
    );
    if (_disposed) return;
    result.match(
      (failure) => _emit(error: failure),
      (newEntries) => _emit(
        entries: _orderedUnique([...newEntries, ...state.entries]),
        clearError: true,
      ),
    );
  }

  /// Re-read mutable photo tombstones without discarding paged history.
  Future<void> reloadRecent() async {
    if (_disposed) return;
    try {
      final result = await repository.loadRecent(squadId, planId: planId);
      if (_disposed) return;
      result.match(
        (failure) => _emit(error: failure),
        (entries) => _emit(
          entries: _orderedUnique([...state.entries, ...entries]),
          clearError: true,
        ),
      );
    } catch (_) {
      _emit(error: const Failure.network(message: '消息更新未确认，请稍后重试'));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    unawaited(_onlineSubscription?.cancel());
    super.dispose();
  }

  static List<TimelineEntry> _orderedUnique(List<TimelineEntry> entries) {
    final byId = <String, TimelineEntry>{
      for (final entry in entries) entry.id: entry,
    };
    final ordered = byId.values.toList()
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return ordered;
  }
}
