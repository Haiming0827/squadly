import 'package:fpdart/fpdart.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/plan_progress.dart';
import '../../domain/entities/plan_task.dart';
import '../../domain/entities/squad_plan.dart';
import '../../domain/repositories/plan_repository.dart';

final class DemoPlanRepository implements PlanRepository {
  const DemoPlanRepository(this._store);

  final DemoAppStore _store;

  @override
  Future<Either<Failure, List<SquadPlan>>> getSquadPlans({
    required String squadId,
  }) async => right(_store.getVisiblePlans(squadId));

  @override
  Future<Either<Failure, Map<String, PlanProgress>>> getSquadPlanProgress({
    required String squadId,
  }) async {
    final progress = <String, PlanProgress>{};
    for (final plan in _store.getVisiblePlans(squadId)) {
      final tasks = _store.getVisiblePlanTasks(plan.id);
      if (tasks.isEmpty) continue;
      progress[plan.id] = PlanProgress(
        completedCount: tasks.where((task) => task.isComplete).length,
        totalCount: tasks.length,
      );
    }
    return right(progress);
  }

  @override
  Future<Either<Failure, SquadPlan>> setPlanStatus({
    required String planId,
    required PlanStatus status,
  }) => _capture(() => _store.setPlanStatus(planId: planId, status: status));

  @override
  Future<Either<Failure, SquadPlan>> createPlan({
    required String squadId,
    required String title,
    required PlanCategory category,
    required PlanVisibility visibility,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) => _capture(
    () => _store.createPlan(
      squadId: squadId,
      title: title,
      category: category,
      visibility: visibility,
      description: description,
      startDate: startDate,
      endDate: endDate,
    ),
  );

  @override
  Future<Either<Failure, SquadPlan>> updatePlan({
    required String planId,
    required String title,
    required PlanCategory category,
    required PlanVisibility visibility,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) => _capture(
    () => _store.updatePlan(
      planId: planId,
      title: title,
      category: category,
      visibility: visibility,
      description: description,
      startDate: startDate,
      endDate: endDate,
    ),
  );

  @override
  Future<Either<Failure, List<PlanTask>>> getPlanTasks({
    required String planId,
  }) async => right(_store.getVisiblePlanTasks(planId));

  @override
  Future<Either<Failure, PlanTask>> createTask({
    required String planId,
    required String squadId,
    required String title,
    String? details,
    String? assignedTo,
    DateTime? dueDate,
  }) => _capture(
    () => _store.createPlanTask(
      planId: planId,
      squadId: squadId,
      title: title,
      details: details,
      assignedTo: assignedTo,
      dueDate: dueDate,
    ),
  );

  @override
  Future<Either<Failure, PlanTask>> setTaskCompletion({
    required String taskId,
    required bool isComplete,
  }) => _capture(
    () => _store.setPlanTaskCompletion(taskId: taskId, isComplete: isComplete),
  );

  Future<Either<Failure, T>> _capture<T>(T Function() action) async {
    try {
      return right(action());
    } on StateError catch (error) {
      final message = error.message;
      if (message.contains('没有操作权限') || message.contains('不是该小队成员')) {
        return left(const Failure.permissionDenied());
      }
      if (message.contains('请先登录')) return left(const Failure.unauthorized());
      return left(Failure.validation(message: message));
    } catch (_) {
      return left(const Failure.unknown());
    }
  }
}
