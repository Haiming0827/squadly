import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/plan/domain/entities/plan_progress.dart';
import '../../features/plan/domain/entities/plan_task.dart';
import '../../features/plan/domain/entities/squad_plan.dart';
import 'current_user_provider.dart';
import 'domain_repository_providers.dart';

/// App-level plan data bindings allow Squad and other features to display
/// shared plan summaries without depending on Plan presentation providers.
final squadPlansProvider = FutureProvider.family<List<SquadPlan>, String>((
  ref,
  squadId,
) async {
  ref.watch(currentUserProvider);
  final result = await ref
      .watch(planRepositoryProvider)
      .getSquadPlans(squadId: squadId);
  return result.match(
    (failure) => throw StateError(_planFailureMessage(failure)),
    (plans) => plans,
  );
});

final squadPlanProgressProvider =
    FutureProvider.family<Map<String, PlanProgress>, String>((
      ref,
      squadId,
    ) async {
      ref.watch(currentUserProvider);
      final result = await ref
          .watch(planRepositoryProvider)
          .getSquadPlanProgress(squadId: squadId);
      return result.match(
        (failure) => throw StateError(_planFailureMessage(failure)),
        (progress) => progress,
      );
    });

final planTasksProvider = FutureProvider.family<List<PlanTask>, String>((
  ref,
  planId,
) async {
  ref.watch(currentUserProvider);
  final result = await ref
      .watch(planRepositoryProvider)
      .getPlanTasks(planId: planId);
  return result.match(
    (failure) => throw StateError(_planFailureMessage(failure)),
    (tasks) => tasks,
  );
});

String _planFailureMessage(Object failure) {
  final message = failure.toString();
  if (message.contains('PermissionDenied')) return '没有查看该计划的权限';
  if (message.contains('Unauthorized')) return '请先登录';
  if (message.contains('Network')) return '网络连接失败，请稍后重试';
  return '计划加载失败，请稍后重试';
}
