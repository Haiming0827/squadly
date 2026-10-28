import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../app/providers/domain_repository_providers.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/travel_snapshot.dart';
import '../../domain/usecases/get_travel_snapshot.dart';

export '../../../../app/providers/domain_repository_providers.dart'
    show travelRepositoryProvider;

final travelSnapshotProvider = FutureProvider.family<TravelSnapshot, String>((
  ref,
  squadId,
) async {
  final result = await GetTravelSnapshot(
    travelRepository: ref.watch(travelRepositoryProvider),
    financeRepository: ref.watch(financeRepositoryProvider),
  )(squadId: squadId);
  return _unwrap(result);
});

T _unwrap<T>(Either<Failure, T> result) => result.fold(
  (failure) => throw StateError(switch (failure) {
    ServerFailure(:final message) => message,
    PermissionDeniedFailure() => '没有查看旅行数据的权限',
    UnauthorizedFailure() => '请先登录',
    NetworkFailure() => '网络连接失败，请稍后重试',
    _ => '旅行数据加载失败',
  }),
  (value) => value,
);
