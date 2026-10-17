import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/cloudbase_client_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../fitness/presentation/providers/fitness_provider.dart';
import '../../data/repositories/cloudbase_food_repository.dart';
import '../../domain/entities/food_spot.dart';
import '../../domain/repositories/food_repository.dart';

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  final app = ref.watch(cloudBaseAppProvider);
  return CloudBaseFoodRepository(
    client: ref.watch(cloudBasePostgresClientProvider).rest,
    currentUserId: () async {
      final response = await app.auth.getSession();
      if (!response.isSuccess) return null;
      return response.data?.session?.user?.id;
    },
  );
});

final foodSnapshotProvider = FutureProvider.family<FoodSnapshot, String>((
  ref,
  squadId,
) async {
  final foods = await ref
      .watch(foodRepositoryProvider)
      .getSquadFoodSpots(squadId: squadId);
  final user = ref.watch(authNotifierProvider).valueOrNull;
  final calories = user == null
      ? left<Failure, int>(const Failure.unauthorized())
      : await ref
            .watch(fitnessRepositoryProvider)
            .getDailyCaloriesBurned(userId: user.id, date: DateTime.now());
  return FoodSnapshot(spots: _unwrap(foods), caloriesBurned: _unwrap(calories));
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

final class FoodSnapshot {
  const FoodSnapshot({required this.spots, required this.caloriesBurned});

  final List<FoodSpot> spots;
  final int caloriesBurned;

  FoodSpot? get recommended {
    if (spots.isEmpty) return null;
    return spots.reduce(
      (current, candidate) =>
          candidate.score > current.score ? candidate : current,
    );
  }
}
