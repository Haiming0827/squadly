import 'package:fpdart/fpdart.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/error/failures.dart';
import '../domain/conversation_preference.dart';

final class CloudBaseConversationCustomization
    implements ConversationCustomizationRepository {
  const CloudBaseConversationCustomization(this.client);
  final PostgrestClient client;
  @override
  Future<Either<Failure, List<ConversationPreference>>> load() async {
    try {
      final rows = await client.rpc('get_conversation_preferences');
      return right([
        for (final row in rows as List)
          ConversationPreference(
            squadId: row['squad_id'] as String,
            remark: row['remark'] as String? ?? '',
            pinnedAt: DateTime.tryParse(row['pinned_at'] as String? ?? ''),
            lastOpenedAt: DateTime.tryParse(
              row['last_opened_at'] as String? ?? '',
            ),
            recentOpenCount: (row['recent_open_count'] as num?)?.toInt() ?? 0,
          ),
      ]);
    } catch (_) {
      return left(const Failure.server(message: '会话设置加载失败，请重试'));
    }
  }

  @override
  Future<Either<Failure, void>> save({
    required String squadId,
    required String remark,
    required bool pinned,
  }) async {
    if (remark.trim().runes.length > 40) {
      return left(const Failure.validation(message: '备注最多 40 个字'));
    }
    return _write('save_conversation_preference', {
      'p_squad_id': squadId,
      'p_remark': remark.trim(),
      'p_pinned': pinned,
    });
  }

  @override
  Future<Either<Failure, void>> recordOpen(String squadId) =>
      _write('record_conversation_open', {'p_squad_id': squadId});
  Future<Either<Failure, void>> _write(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    try {
      final result = await client.rpc(rpc, params: params);
      return switch (result) {
        {'saved': true} => right(null),
        {'error': 'forbidden'} => left(const Failure.permissionDenied()),
        {'error': 'unauthenticated'} => left(const Failure.unauthorized()),
        _ => left(const Failure.validation(message: '会话设置未保存，请检查后重试')),
      };
    } catch (_) {
      return left(const Failure.server(message: '会话设置保存失败，请重试'));
    }
  }
}
