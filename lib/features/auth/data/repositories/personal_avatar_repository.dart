import 'package:fpdart/fpdart.dart';
import 'package:postgrest/postgrest.dart';

import '../../../../core/error/failures.dart';
import '../../../squad/domain/squad_avatar_format.dart';
import '../../domain/repositories/personal_avatar_repository.dart';

final class CloudBasePersonalAvatarRepository
    implements PersonalAvatarRepository {
  const CloudBasePersonalAvatarRepository(this.client, this.userId);
  final PostgrestClient client;
  final String userId;
  @override
  Future<Either<Failure, void>> save(String? avatar) async {
    if (userId.isEmpty) return left(const Failure.unauthorized());
    if (avatar != null && decodeSquadAvatar(avatar) == null) {
      return left(const Failure.validation(message: '请重新选择头像'));
    }
    try {
      final row = await client
          .from('profiles')
          .update({'avatar_url': avatar})
          .eq('id', userId)
          .select('id')
          .single();
      if (row['id'] != userId) return left(const Failure.permissionDenied());
      return right(null);
    } on PostgrestException catch (error) {
      return left(
        error.code == '42501'
            ? const Failure.permissionDenied()
            : const Failure.server(message: '头像保存失败，请稍后重试'),
      );
    } catch (_) {
      return left(const Failure.server(message: '头像保存失败，请稍后重试'));
    }
  }
}
