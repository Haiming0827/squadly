import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/error/failures.dart';
import '../../cards/domain/card_composer.dart';
import '../../secure_route/domain/route_models.dart';
import '../domain/conversation_photo_repository.dart';
import '../domain/conversation_repository.dart';
import '../domain/photo_head.dart';
import '../domain/timeline_entry.dart';
import 'timeline_entry_mapper.dart';

/// CloudBase PG adapter for guarded conversation RPCs. No direct message
/// insert/update is allowed from the app; database functions and RLS own access.
final class CloudBaseConversationRepository
    implements ConversationRepository, ConversationPhotoRepository {
  const CloudBaseConversationRepository(this._client);

  final PostgrestClient _client;

  @override
  Future<Either<Failure, PhotoHead>> photoHead(String squadId) async {
    try {
      final result = await _client.rpc(
        'get_squad_photo_head',
        params: {'p_squad_id': squadId},
      );
      if (result == null) {
        return left(const Failure.permissionDenied(message: '你已无法查看这个小队'));
      }
      final data = _map(result);
      final revision = data['revision'];
      if (revision is! String ||
          !validPhotoHeadRevision(revision) ||
          !data.containsKey('photo')) {
        throw const FormatException('Invalid photo head');
      }
      final entry = data['photo'] == null
          ? null
          : timelineEntryFromJson(_map(data['photo']));
      if (entry != null && (!_validPhoto(entry, squadId) || revision == '0')) {
        throw const FormatException('Invalid photo head');
      }
      return right(PhotoHead(revision: revision, photo: entry));
    } on PostgrestException catch (error) {
      return left(_failure(error));
    } on FormatException {
      return left(const Failure.server(message: '照片数据格式错误'));
    } catch (_) {
      return left(const Failure.network(message: '暂时无法更新小队照片'));
    }
  }

  @override
  Future<Either<Failure, List<TimelineEntry>>> pagePhotos(
    String squadId, {
    TimelineCursor? before,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 50) {
      return left(const Failure.validation(message: '照片分页数量不正确'));
    }
    final result = await _page({
      'p_squad_id': squadId,
      'p_limit': limit,
      if (before != null)
        'p_before_created_at': before.createdAt.toUtc().toIso8601String(),
      if (before != null) 'p_before_id': before.id,
    }, rpcName: 'page_squad_photos');
    return result.flatMap(
      (entries) => entries.every((e) => _validPhoto(e, squadId))
          ? right(entries)
          : left(const Failure.server(message: '照片数据格式错误')),
    );
  }

  @override
  Future<Either<Failure, TimelineEntry?>> findPhoto({
    required String squadId,
    required String messageId,
  }) async {
    try {
      final result = await _client.rpc(
        'get_squad_photo',
        params: {'p_squad_id': squadId, 'p_message_id': messageId},
      );
      if (result == null) return right(null);
      final entry = timelineEntryFromJson(_map(result));
      if (!_validPhoto(entry, squadId) || entry.id != messageId) {
        return left(const Failure.server(message: '照片数据格式错误'));
      }
      return right(entry);
    } on PostgrestException catch (error) {
      return left(_failure(error));
    } on FormatException {
      return left(const Failure.server(message: '照片数据格式错误'));
    } catch (_) {
      return left(const Failure.network(message: '暂时无法查看这张照片'));
    }
  }

  static bool _validPhoto(TimelineEntry entry, String squadId) =>
      entry.squadId == squadId &&
      entry.planId == null &&
      entry.kind == TimelineEntryKind.photo &&
      entry.photo?.isRevoked == false;

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId, {
    String? planId,
  }) => _page({
    'p_squad_id': squadId,
    ...?_planIdParam(planId),
    'p_limit': 50,
  }, planId: planId);

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) => _page({
    'p_squad_id': squadId,
    ...?_planIdParam(planId),
    'p_after_created_at': cursor.createdAt.toUtc().toIso8601String(),
    'p_after_id': cursor.id,
    'p_limit': 50,
  }, planId: planId);

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadBefore(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) => _page({
    'p_squad_id': squadId,
    ...?_planIdParam(planId),
    'p_before_created_at': cursor.createdAt.toUtc().toIso8601String(),
    'p_before_id': cursor.id,
    'p_limit': 50,
  }, planId: planId);

  Future<Either<Failure, List<TimelineEntry>>> _page(
    Map<String, Object> params, {
    String? planId,
    String? rpcName,
  }) async {
    try {
      final result = await _client.rpc(
        rpcName ??
            (planId == null
                ? 'page_squad_timeline'
                : 'page_squad_plan_discussion'),
        params: params,
      );
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
    String? planId,
  }) async {
    try {
      final result = planId == null
          ? await _client.rpc(
              'send_text_message',
              params: {
                'p_squad_id': squadId,
                'p_body': body,
                'p_client_nonce': clientNonce,
                'p_reply_to_message_id': replyToEntryId,
              },
            )
          : await _client.rpc(
              'send_squad_plan_message',
              params: {
                'p_squad_id': squadId,
                'p_plan_id': planId,
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
  Stream<void> watchTimeline(String squadId, {String? planId}) {
    late final StreamController<void> changes;
    Timer? timer;
    changes = StreamController<void>.broadcast(
      onListen: () {
        changes.add(null);
        timer = Timer.periodic(const Duration(seconds: 20), (_) {
          if (!changes.isClosed) changes.add(null);
        });
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );
    return changes.stream;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) throw const FormatException('Expected JSON object');
    return Map<String, dynamic>.from(value);
  }

  static Failure _failure(PostgrestException error) =>
      error.code == '42501' ||
          error.code == 'DATABASE_42501' ||
          error.code == 'PGRST301'
      ? const Failure.permissionDenied(message: '你无权查看或发送这条小队内容')
      : const Failure.server(message: '服务暂时不可用，请稍后重试');
}

Map<String, Object>? _planIdParam(String? planId) =>
    planId == null ? null : {'p_plan_id': planId};
