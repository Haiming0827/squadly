import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/check_in.dart';
import '../entities/daily_task.dart';
import '../entities/health_snapshot.dart';
import '../entities/workout_plan.dart';

/// 健身仓库接口
abstract class FitnessRepository {
  /// 训练计划
  Future<Either<Failure, WorkoutPlan>> createWorkoutPlan({
    required String squadId,
    required String name,
    required String planType,
    String? description,
  });

  Future<Either<Failure, List<WorkoutPlan>>> getSquadWorkoutPlans({
    required String squadId,
  });

  /// 每日任务
  Future<Either<Failure, DailyTask>> createDailyTask({
    required String squadId,
    required String title,
    required String taskType,
    double? targetValue,
    String? targetUnit,
    List<int>? recurringDays,
  });

  Future<Either<Failure, List<DailyTask>>> getSquadDailyTasks({
    required String squadId,
  });

  /// 打卡
  Future<Either<Failure, CheckIn>> checkInTask({
    required String taskId,
    required String squadId,
    double? value,
    String? note,
  });

  Future<Either<Failure, List<CheckIn>>> getSquadCheckIns({
    required String squadId,
    required DateTime date,
  });

  /// 健康数据
  Future<Either<Failure, HealthSnapshot>> recordHealthSnapshot({
    required String squadId,
    double? weight,
    int? workoutMinutes,
    int? caloriesBurned,
  });

  /// 暴露给美食模块的接口
  Future<Either<Failure, int>> getDailyCaloriesBurned({
    required String userId,
    required DateTime date,
  });
}
