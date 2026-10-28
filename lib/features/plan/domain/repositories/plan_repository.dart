import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/plan_progress.dart';
import '../entities/plan_task.dart';
import '../entities/squad_plan.dart';

abstract interface class PlanRepository {
  Future<Either<Failure, List<SquadPlan>>> getSquadPlans({
    required String squadId,
  });

  Future<Either<Failure, Map<String, PlanProgress>>> getSquadPlanProgress({
    required String squadId,
  });

  Future<Either<Failure, SquadPlan>> setPlanStatus({
    required String planId,
    required PlanStatus status,
  });

  Future<Either<Failure, SquadPlan>> createPlan({
    required String squadId,
    required String title,
    required PlanCategory category,
    required PlanVisibility visibility,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Either<Failure, SquadPlan>> updatePlan({
    required String planId,
    required String title,
    required PlanCategory category,
    required PlanVisibility visibility,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Either<Failure, List<PlanTask>>> getPlanTasks({
    required String planId,
  });

  Future<Either<Failure, PlanTask>> createTask({
    required String planId,
    required String squadId,
    required String title,
    String? details,
    String? assignedTo,
    DateTime? dueDate,
  });

  Future<Either<Failure, PlanTask>> setTaskCompletion({
    required String taskId,
    required bool isComplete,
  });
}
