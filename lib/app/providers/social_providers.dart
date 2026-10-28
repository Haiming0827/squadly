import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failures.dart';
import '../../features/social/domain/entities/data_connection.dart';
import '../../features/social/domain/entities/external_data_item.dart';
import '../../features/social/domain/entities/social_post.dart';
import 'current_user_provider.dart';
import 'domain_repository_providers.dart';

final currentSocialUserIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider).value?.id,
);

final myImportedSocialDataProvider = FutureProvider<List<ExternalDataItem>>((
  ref,
) async {
  final result = await ref.watch(socialRepositoryProvider).getMyImportedData();
  return result.fold(
    (failure) => throw StateError(_socialFailureMessage(failure)),
    (items) => items,
  );
});

final mySocialConnectionsProvider = FutureProvider<List<DataConnection>>((
  ref,
) async {
  final result = await ref.watch(socialRepositoryProvider).getMyConnections();
  return result.fold(
    (failure) => throw StateError(_socialFailureMessage(failure)),
    (connections) => connections,
  );
});

final squadSocialPostsProvider = StreamProvider.autoDispose
    .family<List<SocialPost>, String>((ref, squadId) {
      return ref
          .watch(socialRepositoryProvider)
          .watchPosts(squadId)
          .map(
            (result) => result.fold(
              (failure) => throw StateError(_socialFailureMessage(failure)),
              (posts) => posts,
            ),
          );
    });

String _socialFailureMessage(Failure failure) => switch (failure) {
  UnauthorizedFailure() => '请先登录后查看小队动态',
  PermissionDeniedFailure() => '你无权查看这些分享',
  NetworkFailure() => '网络连接失败，请稍后重试',
  NotFoundFailure() => '没有找到这条分享',
  ValidationFailure() => '分享内容无效',
  ServerFailure() || UnknownFailure() => '动态加载失败，请稍后重试',
  SquadFullFailure() || SquadMinMembersFailure() => '小队状态发生变化，请刷新重试',
};
