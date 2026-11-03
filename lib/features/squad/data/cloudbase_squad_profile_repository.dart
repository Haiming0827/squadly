import 'package:fpdart/fpdart.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/error/failures.dart';
import '../domain/repositories/squad_profile_repository.dart';
import '../domain/squad_avatar_format.dart';

final class CloudBaseSquadProfileRepository implements SquadProfileRepository {
  const CloudBaseSquadProfileRepository(this.client);
  final PostgrestClient client;
  @override
  Future<Either<Failure, void>> save({
    required String squadId,
    required String name,
    required String description,
    required String? avatar,
  }) async {
    if (name.trim().isEmpty ||
        name.trim().runes.length > 40 ||
        description.runes.length > 200) {
      return left(
        const Failure.validation(message: '名称需为 1–40 个字，简介最多 200 个字'),
      );
    }
    if (avatar != null && decodeSquadAvatar(avatar) == null) {
      return left(const Failure.validation(message: '请重新选择头像'));
    }
    try {
      final result = await client.rpc(
        'update_squad_profile',
        params: {
          'p_squad_id': squadId,
          'p_name': name.trim(),
          'p_description': description.trim(),
          'p_avatar': avatar,
        },
      );
      return switch (result) {
        {'saved': true} => right(null),
        {'error': 'forbidden'} => left(
          const Failure.permissionDenied(message: '仅队长可修改小队资料'),
        ),
        {'error': 'unauthenticated'} => left(const Failure.unauthorized()),
        _ => left(const Failure.validation(message: '小队资料未保存，请检查后重试')),
      };
    } catch (_) {
      return left(const Failure.server(message: '小队资料保存失败，请重试'));
    }
  }
}
