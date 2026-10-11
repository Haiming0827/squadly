import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/failures.dart';
import '../../cards/domain/card_composer.dart';
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
  }) : super(ConversationState(entries: const []));

  final ConversationRepository repository;
  final ConversationOutbox outbox;
  final String squadId;
  final String currentUserId;

  StreamSubscription<void>? _subscription;
  bool _disposed = false;
  bool _refreshing = false;
  bool _refreshRequested = false;
  bool _draining = false;
  final _inFlightNonces = <String>{};
  static const _pageSize = 50;

  void _emit({
    List<TimelineEntry>? entries,
    bool isLoading = false,
    Object? error,
    int? pendingCount,
  }) {
    if (_disposed) return;
    state = ConversationState(
      entries: entries ?? state.entries,
      isLoading: isLoading,
      error: error,
      pendingCount: pendingCount ?? state.pendingCount,
    );
  }

  Future<void> initialize() async {
    if (_disposed) return;
    _emit(isLoading: true);
    _subscription ??= repository.watchTimeline(squadId).listen((_) {
      unawaited(refresh());
    });
    final result = await repository.loadRecent(squadId);
    if (_disposed) return;
    result.match(
      (failure) => _emit(error: failure),
      (entries) =>
          _emit(entries: _orderedUnique([...state.entries, ...entries])),
    );
    await retryPending();
  }

  Future<Either<Failure, TimelineEntry>> sendText(
    String body, {
    String? replyToEntryId,
  }) async {
    final normalized = body.trim();
    if (normalized.isEmpty) {
      return left(const Failure.validation(message: '消息不能为空'));
    }
    if (currentUserId.isEmpty) {
      return left(const Failure.unauthorized(message: '请先登录'));
    }
    if (replyToEntryId != null &&
        !state.entries.any(
          (entry) => entry.id == replyToEntryId && entry.squadId == squadId,
        )) {
      return left(const Failure.validation(message: '回复目标已不可见，请刷新会话'));
    }
    try {
      final pending = await outbox.listFor(
        userId: currentUserId,
        squadId: squadId,
      );
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
      );
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

  Future<Either<Failure, TimelineEntry>> _sendPending(
    PendingConversationOperation operation,
  ) async {
    _inFlightNonces.add(operation.clientNonce);
    try {
      final result = switch (operation) {
        PendingTextOperation(:final body, :final replyToEntryId) =>
          await repository.sendText(
            squadId: squadId,
            body: body,
            clientNonce: operation.clientNonce,
            replyToEntryId: replyToEntryId,
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
      );
      _emit(
        entries: _orderedUnique([...state.entries, entry]),
        pendingCount: state.pendingCount > 0 ? state.pendingCount - 1 : 0,
      );
    } catch (_) {
      // The server ack is authoritative. A later retry with the same nonce
      // can safely clean up the local entry without inserting another row.
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
      );
      _emit(pendingCount: pending.length);
      for (final operation in pending) {
        if (_disposed) break;
        if (_inFlightNonces.contains(operation.clientNonce)) continue;
        await _sendPending(operation);
      }
    } catch (_) {
      _emit(error: const Failure.server(message: '本机待发队列无法读取，请检查设备存储'));
    } finally {
      _draining = false;
    }
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
              ? await repository.loadRecent(squadId)
              : await repository.loadAfter(squadId, entries.last.cursor);
          if (_disposed) return;
          final page = result.match<List<TimelineEntry>?>(
            (failure) {
              _emit(error: failure);
              return null;
            },
            (newEntries) {
              _emit(entries: _orderedUnique([...state.entries, ...newEntries]));
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
      } while (_refreshRequested && !_disposed);
      await retryPending();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> loadEarlier() async {
    if (_disposed || state.entries.isEmpty) return;
    final result = await repository.loadBefore(
      squadId,
      state.entries.first.cursor,
    );
    if (_disposed) return;
    result.match(
      (failure) => _emit(error: failure),
      (newEntries) =>
          _emit(entries: _orderedUnique([...newEntries, ...state.entries])),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
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
