import 'package:fpdart/fpdart.dart';
import 'package:postgrest/postgrest.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/plan_progress.dart';
import '../../domain/entities/plan_task.dart';
import '../../domain/entities/squad_plan.dart';
import '../../domain/repositories/plan_repository.dart';

typedef CurrentPlanUserId = Future<String?> Function();

final class CloudBasePlanRepository implements PlanRepository {
  const CloudBasePlanRepository({
    required this._client,
    required this._currentUserId,
  });

  final PostgrestClient _client;
  final CurrentPlanUserId _currentUserId;

  @override
  Future<Either<Failure, List<SquadPlan>>> getSquadPlans({
    required String squadId,
  }) => _capture(() async {
    final rows = await _client
        .from('squad_plans')
        .select()
        .eq('squad_id', squadId)
        .order('updated_at', ascending: false);
    return (rows as List).map((row) => _plan(_map(row))).toList();
  });

  @override
  Future<Either<Failure, Map<String, PlanProgress>>> getSquadPlanProgress({
    required String squadId,
  }) => _capture(() async {
    final rows = await _client
        .from('squad_plan_tasks')
        .select('plan_id,is_complete')
        .eq('squad_id', squadId);
    final counts = <String, (int completed, int total)>{};
    for (final rawRow in rows as List) {
      final row = _map(rawRow);
      final planId = row['plan_id'] as String;
      final isComplete = row['is_complete'] as bool;
      final current = counts[planId] ?? (0, 0);
      counts[planId] = (current.$1 + (isComplete ? 1 : 0), current.$2 + 1);
    }
    return {
      for (final entry in counts.entries)
        entry.key: PlanProgress(
          completedCount: entry.value.$1,
          totalCount: entry.value.$2,
        ),
    };
  });

  @override
  Future<Either<Failure, SquadPlan>> setPlanStatus({
    required String planId,
    required PlanStatus status,
  }) => _capture(() async {
    await _requireUserId();
    final row = await _client
        .from('squad_plans')
        .update({
          'status': planStatusToDb(status),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', planId)
        .select()
        .single();
    return _plan(_map(row));
  });

  @override
  Future<Either<Failure, SquadPlan>> createPlan({
    required String squadId,
    required String title,
    required PlanCategory category,
    required PlanVisibility visibility,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) => _capture(() async {
    final userId = await _requireUserId();
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty || trimmedTitle.length > 100) {
      throw const _InvalidPlan('计划名称需为 1–100 个字符');
    }
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      throw const _InvalidPlan('结束日期不能早于开始日期');
    }
    final row = await _client
        .from('squad_plans')
        .insert({
          'squad_id': squadId,
          'title': trimmedTitle,
          'description': _text(description),
          'category': planCategoryToDb(category),
          'visibility': planVisibilityToDb(visibility),
          'start_date': _date(startDate),
          'end_date': _date(endDate),
          'created_by': userId,
        })
        .select()
        .single();
    return _plan(_map(row));
  });

  @override
  Future<Either<Failure, SquadPlan>> updatePlan({
    required String planId,
    required String title,
    required PlanCategory category,
    required PlanVisibility visibility,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) => _capture(() async {
    await _requireUserId();
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty || trimmedTitle.length > 100) {
      throw const _InvalidPlan('计划名称需为 1–100 个字符');
    }
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      throw const _InvalidPlan('结束日期不能早于开始日期');
    }
    final now = DateTime.now().toUtc();
    final row = await _client
        .from('squad_plans')
        .update({
          'title': trimmedTitle,
          'description': _text(description),
          'category': planCategoryToDb(category),
          'visibility': planVisibilityToDb(visibility),
          'start_date': _date(startDate),
          'end_date': _date(endDate),
          'updated_at': now.toIso8601String(),
        })
        .eq('id', planId)
        .select()
        .single();
    return _plan(_map(row));
  });

  @override
  Future<Either<Failure, List<PlanTask>>> getPlanTasks({
    required String planId,
  }) => _capture(() async {
    final rows = await _client
        .from('squad_plan_tasks')
        .select()
        .eq('plan_id', planId)
        .order('position')
        .order('created_at');
    return (rows as List).map((row) => _task(_map(row))).toList();
  });

  @override
  Future<Either<Failure, PlanTask>> createTask({
    required String planId,
    required String squadId,
    required String title,
    String? details,
    String? assignedTo,
    DateTime? dueDate,
  }) => _capture(() async {
    final userId = await _requireUserId();
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty || trimmedTitle.length > 160) {
      throw const _InvalidPlan('任务名称需为 1–160 个字符');
    }
    final row = await _client
        .from('squad_plan_tasks')
        .insert({
          'plan_id': planId,
          'squad_id': squadId,
          'title': trimmedTitle,
          'details': _text(details),
          'assigned_to': assignedTo,
          'due_date': _date(dueDate),
          'created_by': userId,
        })
        .select()
        .single();
    return _task(_map(row));
  });

  @override
  Future<Either<Failure, PlanTask>> setTaskCompletion({
    required String taskId,
    required bool isComplete,
  }) => _capture(() async {
    final userId = await _requireUserId();
    final now = DateTime.now().toUtc();
    final row = await _client
        .from('squad_plan_tasks')
        .update({
          'is_complete': isComplete,
          'completed_by': isComplete ? userId : null,
          'completed_at': isComplete ? now.toIso8601String() : null,
          'updated_at': now.toIso8601String(),
        })
        .eq('id', taskId)
        .select()
        .single();
    return _task(_map(row));
  });

  Future<String> _requireUserId() async {
    final userId = await _currentUserId();
    if (userId == null || userId.isEmpty) throw const _Unauthenticated();
    return userId;
  }

  Future<Either<Failure, T>> _capture<T>(Future<T> Function() operation) async {
    try {
      return right(await operation());
    } on _Unauthenticated {
      return left(const Failure.unauthorized());
    } on _InvalidPlan catch (error) {
      return left(Failure.validation(message: error.message));
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        return left(const Failure.permissionDenied());
      }
      if (error.code == '23514') {
        return left(const Failure.validation(message: '计划信息不符合要求'));
      }
      if (error.code == '23503') {
        return left(const Failure.validation(message: '小队、计划或成员不存在'));
      }
      if (error.code == 'PGRST116') return left(const Failure.notFound());
      return left(const Failure.server(message: '计划数据操作失败'));
    } on FormatException {
      return left(const Failure.server(message: '计划数据格式无效'));
    } catch (_) {
      return left(const Failure.network(message: '无法连接计划服务'));
    }
  }

  SquadPlan _plan(Map<String, dynamic> row) => SquadPlan(
    id: row['id'] as String,
    squadId: row['squad_id'] as String,
    title: row['title'] as String,
    description: row['description'] as String?,
    category: planCategoryFromDb(row['category'] as String),
    visibility: planVisibilityFromDb(row['visibility'] as String),
    status: planStatusFromDb(row['status'] as String),
    startDate: _parseDate(row['start_date'] as String?),
    endDate: _parseDate(row['end_date'] as String?),
    createdBy: row['created_by'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    legacySource: row['legacy_source'] as String?,
    legacyId: row['legacy_id'] as String?,
    legacyData: row['legacy_data'] is Map
        ? Map.unmodifiable(Map<String, dynamic>.from(row['legacy_data'] as Map))
        : const {},
  );

  PlanTask _task(Map<String, dynamic> row) => PlanTask(
    id: row['id'] as String,
    planId: row['plan_id'] as String,
    squadId: row['squad_id'] as String,
    title: row['title'] as String,
    details: row['details'] as String?,
    assignedTo: row['assigned_to'] as String?,
    dueDate: _parseDate(row['due_date'] as String?),
    isComplete: row['is_complete'] as bool,
    completedBy: row['completed_by'] as String?,
    completedAt: _parseTimestamp(row['completed_at'] as String?),
    position: (row['position'] as num).toInt(),
    createdBy: row['created_by'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}

Map<String, dynamic> _map(Object? row) => Map<String, dynamic>.from(row as Map);
String? _text(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();
String? _date(DateTime? value) => value?.toIso8601String().split('T').first;
DateTime? _parseDate(String? value) =>
    value == null ? null : DateTime.parse(value);
DateTime? _parseTimestamp(String? value) =>
    value == null ? null : DateTime.parse(value);

final class _Unauthenticated implements Exception {
  const _Unauthenticated();
}

final class _InvalidPlan implements Exception {
  const _InvalidPlan(this.message);

  final String message;
}
