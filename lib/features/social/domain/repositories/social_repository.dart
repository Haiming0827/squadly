import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/data_connection.dart';
import '../entities/external_data_item.dart';
import '../entities/social_post.dart';

/// 社交与外部数据分享的数据访问边界。
abstract interface class SocialRepository {
  Future<Either<Failure, List<ExternalDataItem>>> getMyImportedData();

  Future<Either<Failure, List<DataConnection>>> getMyConnections();

  Future<Either<Failure, ExternalDataItem>> importDataItem({
    required ExternalDataItem item,
  });

  Stream<Either<Failure, List<SocialPost>>> watchPosts(String squadId);

  Future<Either<Failure, SocialPost>> publishDataPost({
    required String squadId,
    required String dataItemId,
    required String title,
    required String body,
    required String template,
    required String visibility,
    List<String> visibleToUserIds,
  });

  Future<Either<Failure, bool>> togglePostReaction({
    required String postId,
    required String squadId,
  });
}
