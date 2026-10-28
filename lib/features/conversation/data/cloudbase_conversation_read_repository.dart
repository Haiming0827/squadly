import 'package:fpdart/fpdart.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/error/failures.dart';
import '../domain/conversation_read_repository.dart';
import '../domain/conversation_target.dart';
import '../domain/message_read_receipt.dart';

/// Transport for guarded cursor RPCs. The table itself is never written by the
/// client, and errors never include response bodies or SDK exception text.
final class CloudBaseConversationReadRepository
    implements ConversationReadRepository {
  const CloudBaseConversationReadRepository(this._client);

  final PostgrestClient _client;
  static const _invalid = Failure.validation(message: '已读请求无效，请刷新会话');
  static const _unavailable = Failure.server(message: '已读状态暂不可用');

  @override
  Future<Either<Failure, Unit>> advance({
    required ConversationTarget target,
    required String messageId,
  }) async {
    if (!_validTarget(target) || messageId.isEmpty) return left(_invalid);
    try {
      final result = await _client.rpc(
        'advance_conversation_read_cursor',
        params: {..._targetParams(target), 'p_message_id': messageId},
      );
      if (result != true) return left(_unavailable);
      return right(unit);
    } on PostgrestException catch (error) {
      return left(_failure(error));
    } catch (_) {
      return left(const Failure.network(message: '无法同步已读状态'));
    }
  }

  @override
  Future<Either<Failure, List<MessageReadReceipt>>> loadForMessages({
    required ConversationTarget target,
    required List<String> messageIds,
  }) async {
    if (!_validTarget(target) ||
        messageIds.length > 50 ||
        messageIds.any((id) => id.isEmpty) ||
        messageIds.toSet().length != messageIds.length) {
      return left(_invalid);
    }
    if (messageIds.isEmpty) return right(const []);
    // Snapshot the request before awaiting transport; the caller can retain
    // and modify its own list while the network operation is in flight.
    final requested = List<String>.unmodifiable(messageIds);
    try {
      final result = await _client.rpc(
        'get_message_read_receipts',
        params: {..._targetParams(target), 'p_message_ids': requested},
      );
      if (result is! List || result.length != requested.length) {
        return left(_unavailable);
      }
      final receipts = result.map(_receipt).toList();
      final ids = receipts.map((receipt) => receipt.messageId).toSet();
      if (ids.length != requested.length ||
          ids.difference(requested.toSet()).isNotEmpty) {
        return left(_unavailable);
      }
      return right(List.unmodifiable(receipts));
    } on PostgrestException catch (error) {
      return left(_failure(error));
    } on FormatException {
      return left(_unavailable);
    } catch (_) {
      return left(const Failure.network(message: '无法读取已读状态'));
    }
  }

  static MessageReadReceipt _receipt(Object? value) {
    if (value is! Map || value['members'] is! List) {
      throw const FormatException('Invalid receipt');
    }
    final rows = value['members'] as List;
    if (rows.length > 9) throw const FormatException('Invalid member count');
    final members = rows.map((row) {
      if (row is! Map) throw const FormatException('Invalid member');
      final status = switch (row['status']) {
        'read' => ConversationReadStatus.read,
        'unread' => ConversationReadStatus.unread,
        'not_applicable' => ConversationReadStatus.notApplicable,
        _ => throw const FormatException('Invalid read status'),
      };
      return MemberReadReceipt(
        membershipId: _string(row['membership_id']),
        userId: _string(row['user_id']),
        nickname: _string(row['nickname']),
        status: status,
      );
    }).toList();
    if (members.map((m) => m.userId).toSet().length != members.length ||
        members.map((m) => m.membershipId).toSet().length != members.length) {
      throw const FormatException('Duplicate member');
    }
    return MessageReadReceipt(
      messageId: _string(value['message_id']),
      members: List.unmodifiable(members),
    );
  }

  static String _string(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Invalid field');
    }
    return value;
  }

  static bool _validTarget(ConversationTarget target) =>
      target.squadId.isNotEmpty && target.planId != '';

  static Map<String, Object?> _targetParams(ConversationTarget target) => {
    'p_squad_id': target.squadId,
    'p_plan_id': target.planId,
  };

  static Failure _failure(PostgrestException error) => switch (error.code) {
    '42501' || 'DATABASE_42501' => const Failure.permissionDenied(
      message: '无权查看或更新此会话已读状态',
    ),
    'PGRST301' || 'PGRST302' => const Failure.unauthorized(message: '请重新登录'),
    _ => _unavailable,
  };
}
