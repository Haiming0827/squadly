import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../app/providers/current_user_provider.dart';
import '../../../../app/providers/domain_repository_providers.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/check_in.dart';
import '../../domain/entities/daily_task.dart';
import '../../domain/entities/workout_plan.dart';

export '../../../../app/providers/domain_repository_providers.dart'
    show fitnessRepositoryProvider;

final fitnessSnapshotProvider = FutureProvider.family<FitnessSnapshot, String>((
  ref,
  squadId,
) async {
  final repository = ref.watch(fitnessRepositoryProvider);
  final user = ref.watch(currentUserProvider).value;
  final tasks = await repository.getSquadDailyTasks(squadId: squadId);
  final checkIns = await repository.getSquadCheckIns(
    squadId: squadId,
    date: DateTime.now(),
  );
  final plans = await repository.getSquadWorkoutPlans(squadId: squadId);
  final calories = user == null
      ? left<Failure, int>(const Failure.unauthorized())
      : await repository.getDailyCaloriesBurned(
          userId: user.id,
          date: DateTime.now(),
        );
  return FitnessSnapshot(
    tasks: _unwrap(tasks),
    checkIns: _unwrap(checkIns),
    plans: _unwrap(plans),
    calories: _unwrap(calories),
  );
});

T _unwrap<T>(Either<Failure, T> result) => result.fold(
  (failure) => throw StateError(_fitnessFailureMessage(failure)),
  (value) => value,
);

String _fitnessFailureMessage(Failure failure) => switch (failure) {
  ServerFailure(:final message) => message,
  ValidationFailure(:final message) => message,
  UnauthorizedFailure() => '请先登录',
  PermissionDeniedFailure() => '没有查看健身数据的权限',
  NotFoundFailure() => '健身数据不存在',
  NetworkFailure() => '网络连接失败，请稍后重试',
  _ => '健身数据加载失败',
};

final class FitnessSnapshot {
  const FitnessSnapshot({
    required this.tasks,
    required this.checkIns,
    required this.plans,
    required this.calories,
  });

  final List<DailyTask> tasks;
  final List<CheckIn> checkIns;
  final List<WorkoutPlan> plans;
  final int calories;
}
