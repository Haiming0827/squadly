import 'package:fpdart/fpdart.dart';
import 'package:postgrest/postgrest.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/check_in.dart';
import '../../domain/entities/daily_task.dart';
import '../../domain/entities/health_snapshot.dart';
import '../../domain/entities/workout_plan.dart';
import '../../domain/repositories/fitness_repository.dart';

typedef CurrentFitnessUserId = Future<String?> Function();

final class CloudBaseFitnessRepository implements FitnessRepository {
  const CloudBaseFitnessRepository({
    required this._client,
    required this._currentUserId,
  });

  final PostgrestClient _client;
  final CurrentFitnessUserId _currentUserId;

  @override
  Future<Either<Failure, WorkoutPlan>> createWorkoutPlan({
    required String squadId,
    required String name,
    required String planType,
    String? description,
  }) => _capture(() async {
    final userId = await _requireUserId();
    final row = await _client
        .from('workout_plans')
        .insert({
          'squad_id': squadId,
          'name': name.trim(),
          'plan_type': planType,
          'description': _text(description),
          'created_by': userId,
        })
        .select()
        .single();
    return _plan(_map(row));
  });

  @override
  Future<Either<Failure, List<WorkoutPlan>>> getSquadWorkoutPlans({
    required String squadId,
  }) => _capture(() async {
    final rows = await _client
        .from('workout_plans')
        .select()
        .eq('squad_id', squadId)
        .order('created_at', ascending: false);
    return (rows as List).map((row) => _plan(_map(row))).toList();
  });

  @override
  Future<Either<Failure, DailyTask>> createDailyTask({
    required String squadId,
    required String title,
    required String taskType,
    double? targetValue,
    String? targetUnit,
    List<int>? recurringDays,
  }) => _capture(() async {
    final userId = await _requireUserId();
    final row = await _client
        .from('daily_tasks')
        .insert({
          'squad_id': squadId,
          'title': title.trim(),
          'task_type': taskType,
          'target_value': targetValue,
          'target_unit': _text(targetUnit),
          'recurring_days': recurringDays ?? [1, 2, 3, 4, 5, 6, 7],
          'created_by': userId,
        })
        .select()
        .single();
    return _task(_map(row));
  });

  @override
  Future<Either<Failure, List<DailyTask>>> getSquadDailyTasks({
    required String squadId,
  }) => _capture(() async {
    final rows = await _client
        .from('daily_tasks')
        .select()
        .eq('squad_id', squadId)
        .eq('is_active', true)
        .order('created_at');
    return (rows as List).map((row) => _task(_map(row))).toList();
  });

  @override
  Future<Either<Failure, CheckIn>> checkInTask({
    required String taskId,
    required String squadId,
    double? value,
    String? note,
  }) => _capture(() async {
    final userId = await _requireUserId();
    final row = await _client
        .from('check_ins')
        .insert({
          'task_id': taskId,
          'squad_id': squadId,
          'user_id': userId,
          'value': value,
          'note': _text(note),
          'checked_at': _date(DateTime.now()),
        })
        .select()
        .single();
    return _checkIn(_map(row));
  });

  @override
  Future<Either<Failure, List<CheckIn>>> getSquadCheckIns({
    required String squadId,
    required DateTime date,
  }) => _capture(() async {
    final rows = await _client
        .from('check_ins')
        .select()
        .eq('squad_id', squadId)
        .eq('checked_at', _date(date))
        .order('created_at');
    return (rows as List).map((row) => _checkIn(_map(row))).toList();
  });

  @override
  Future<Either<Failure, HealthSnapshot>> recordHealthSnapshot({
    required String squadId,
    double? weight,
    int? workoutMinutes,
    int? caloriesBurned,
  }) => _capture(() async {
    final userId = await _requireUserId();
    final date = DateTime.now();
    final row = await _client
        .from('health_snapshots')
        .upsert({
          'user_id': userId,
          'squad_id': squadId,
          'weight': weight,
          'workout_minutes': workoutMinutes,
          'calories_burned': caloriesBurned,
          'recorded_date': _date(date),
        }, onConflict: 'user_id,squad_id,recorded_date')
        .select()
        .single();
    return _healthSnapshot(_map(row));
  });

  @override
  Future<Either<Failure, int>> getDailyCaloriesBurned({
    required String userId,
    required DateTime date,
  }) => _capture(() async {
    final ownerId = await _requireUserId();
    if (ownerId != userId) {
      throw const _NotAuthorized();
    }
    final rows = await _client
        .from('health_snapshots')
        .select('calories_burned')
        .eq('user_id', ownerId)
        .eq('recorded_date', _date(date));
    return (rows as List).fold<int>(
      0,
      (total, row) =>
          total + ((_map(row)['calories_burned'] as num?)?.toInt() ?? 0),
    );
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
    } on _NotAuthorized {
      return left(const Failure.permissionDenied());
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        return left(const Failure.permissionDenied());
      }
      if (error.code == '23505') {
        return left(const Failure.validation(message: '今天已经完成该任务打卡'));
      }
      if (error.code == 'PGRST116') return left(const Failure.notFound());
      return left(const Failure.server(message: '健身数据操作失败'));
    } catch (_) {
      return left(const Failure.network(message: '无法连接健身服务'));
    }
  }

  WorkoutPlan _plan(Map<String, dynamic> row) => WorkoutPlan(
    id: row['id'] as String,
    squadId: row['squad_id'] as String,
    name: row['name'] as String,
    planType: row['plan_type'] as String,
    description: row['description'] as String?,
    createdBy: row['created_by'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  DailyTask _task(Map<String, dynamic> row) => DailyTask(
    id: row['id'] as String,
    squadId: row['squad_id'] as String,
    title: row['title'] as String,
    taskType: row['task_type'] as String,
    targetValue: (row['target_value'] as num?)?.toDouble(),
    targetUnit: row['target_unit'] as String?,
    recurringDays: (row['recurring_days'] as List?)?.cast<int>() ?? const [],
    isActive: row['is_active'] as bool? ?? true,
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  CheckIn _checkIn(Map<String, dynamic> row) => CheckIn(
    id: row['id'] as String,
    taskId: row['task_id'] as String,
    userId: row['user_id'] as String,
    squadId: row['squad_id'] as String,
    value: (row['value'] as num?)?.toDouble(),
    note: row['note'] as String?,
    checkedAt: DateTime.parse(row['checked_at'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  HealthSnapshot _healthSnapshot(Map<String, dynamic> row) => HealthSnapshot(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    squadId: row['squad_id'] as String,
    weight: (row['weight'] as num?)?.toDouble(),
    workoutMinutes: (row['workout_minutes'] as num?)?.toInt(),
    caloriesBurned: (row['calories_burned'] as num?)?.toInt(),
    recordedDate: DateTime.parse(row['recorded_date'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

Map<String, dynamic> _map(Object? row) => Map<String, dynamic>.from(row as Map);
String? _text(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();
String _date(DateTime value) => value.toIso8601String().split('T').first;

final class _Unauthenticated implements Exception {
  const _Unauthenticated();
}

final class _NotAuthorized implements Exception {
  const _NotAuthorized();
}
