import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failures.dart';
import '../../cards/domain/card_composer.dart';
import '../../secure_route/domain/route_models.dart';
import '../domain/conversation_repository.dart';
import '../domain/timeline_entry.dart';
import 'timeline_entry_mapper.dart';

/// Production adapter for the guarded conversation RPCs. No direct table
/// insert/update is allowed from the app; RLS and RPCs own membership checks.
final class SupabaseConversationRepository implements ConversationRepository {
  const SupabaseConversationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(String squadId) =>
      _page({'p_squad_id': squadId, 'p_limit': 50});

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor,
  ) => _page({
    'p_squad_id': squadId,
    'p_after_created_at': cursor.createdAt.toUtc().toIso8601String(),
    'p_after_id': cursor.id,
    'p_limit': 50,
  });

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadBefore(
    String squadId,
    TimelineCursor cursor,
  ) => _page({
    'p_squad_id': squadId,
    'p_before_created_at': cursor.createdAt.toUtc().toIso8601String(),
    'p_before_id': cursor.id,
    'p_limit': 50,
  });

  Future<Either<Failure, List<TimelineEntry>>> _page(
    Map<String, Object> params,
  ) async {
    try {
      final result = await _client.rpc('page_squad_timeline', params: params);
      if (result is! List) {
        return left(const Failure.server(message: '会话数据格式错误'));
      }
      return right(
        List.unmodifiable(
          result.map((row) => timelineEntryFromJson(_map(row))),
        ),
      );
    } on PostgrestException catch (error) {
      return left(_failure(error));
    } on FormatException {
      return left(const Failure.server(message: '会话数据格式错误'));
    } catch (_) {
      return left(const Failure.network(message: '无法同步小队消息'));
    }
  }

  @override
  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
  }) async {
    try {
      final result = await _client.rpc(
        'send_text_message',
        params: {
          'p_squad_id': squadId,
          'p_body': body,
          'p_client_nonce': clientNonce,
          'p_reply_to_message_id': replyToEntryId,
        },
      );
      return right(timelineEntryFromJson(_map(result)));
    } on PostgrestException catch (error) {
      return left(_failure(error));
    } on FormatException {
      return left(const Failure.server(message: '消息数据格式错误'));
    } catch (_) {
      return left(const Failure.network(message: '消息发送失败，请稍后重试'));
    }
  }

  @override
  Future<Either<Failure, TimelineEntry>> publishCard({
    required String squadId,
    required String cardId,
    required CardSnapshot snapshot,
    required String clientNonce,
    EncryptedRouteBundle? encryptedRoute,
  }) async {
    if (snapshot.hasEncryptedRoute != (encryptedRoute != null)) {
      return left(const Failure.validation(message: '卡片路线加密状态不一致'));
    }
    try {
      final result = await _client.rpc(
        'publish_card_message',
        params: {
          'p_squad_id': squadId,
          'p_kind': snapshot.kind.name,
          'p_snapshot': snapshot.payload,
          'p_template_id': snapshot.templateId,
          'p_template_version': snapshot.templateVersion,
          'p_client_nonce': clientNonce,
          'p_card_id': cardId,
          'p_route_bundle': encryptedRoute?.toJson(),
        },
      );
      return right(timelineEntryFromJson(_map(result)));
    } on PostgrestException catch (error) {
      return left(_failure(error));
    } on FormatException {
      return left(const Failure.server(message: '卡片数据格式错误'));
    } catch (_) {
      return left(const Failure.network(message: '卡片发布失败，请稍后重试'));
    }
  }

  @override
  Future<Either<Failure, Map<String, String>>> loadMessageTexts({
    required String squadId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty || messageIds.length > 6) {
      return left(const Failure.validation(message: '卡片消息数量不正确'));
    }
    try {
      final rows = await _client
          .from('squad_messages')
          .select('id, body')
          .eq('squad_id', squadId)
          .eq('kind', 'text')
          .inFilter('id', messageIds);
      final texts = <String, String>{
        for (final row in rows) row['id'] as String: row['body'] as String,
      };
      if (texts.length != messageIds.length) {
        return left(const Failure.notFound(message: '卡片引用的消息已不可见'));
      }
      return right(Map.unmodifiable(texts));
    } on PostgrestException catch (error) {
      return left(_failure(error));
    } catch (_) {
      return left(const Failure.network(message: '无法读取卡片引用的消息'));
    }
  }

  @override
  Stream<void> watchTimeline(String squadId) {
    RealtimeChannel? channel;
    late final StreamController<void> changes;
    changes = StreamController<void>.broadcast(
      onListen: () {
        channel = _client
            .channel('squad-messages:$squadId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'squad_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'squad_id',
                value: squadId,
              ),
              callback: (_) {
                if (!changes.isClosed) changes.add(null);
              },
            )
            .subscribe();
      },
      onCancel: () {
        final activeChannel = channel;
        if (activeChannel != null) {
          unawaited(_client.removeChannel(activeChannel));
          channel = null;
        }
      },
    );
    return changes.stream;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) throw const FormatException('Expected JSON object');
    return Map<String, dynamic>.from(value);
  }

  static Failure _failure(PostgrestException error) =>
      error.code == '42501' || error.code == 'PGRST301'
      ? const Failure.permissionDenied(message: '你无权查看或发送这条小队内容')
      : const Failure.server(message: '服务暂时不可用，请稍后重试');
}
