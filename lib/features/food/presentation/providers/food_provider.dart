import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../app/providers/current_user_provider.dart';
import '../../../../app/providers/domain_repository_providers.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/food_snapshot.dart';
import '../../domain/usecases/get_food_snapshot.dart';

export '../../../../app/providers/domain_repository_providers.dart'
    show foodRepositoryProvider;

final foodSnapshotProvider = FutureProvider.family<FoodSnapshot, String>((
  ref,
  squadId,
) async {
  final user = ref.watch(currentUserProvider).value;
  final result = await GetFoodSnapshot(
    foodRepository: ref.watch(foodRepositoryProvider),
    fitnessRepository: ref.watch(fitnessRepositoryProvider),
  )(squadId: squadId, userId: user?.id, date: DateTime.now());
  return _unwrap(result);
});

T _unwrap<T>(Either<Failure, T> result) => result.fold(
  (failure) => throw StateError(switch (failure) {
    ServerFailure(:final message) => message,
    PermissionDeniedFailure() => '没有查看美食数据的权限',
    UnauthorizedFailure() => '请先登录',
    NetworkFailure() => '网络连接失败，请稍后重试',
    _ => '美食数据加载失败',
  }),
  (value) => value,
);
