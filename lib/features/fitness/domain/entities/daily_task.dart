import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_task.freezed.dart';
part 'daily_task.g.dart';

/// 每日打卡任务实体
@freezed
abstract class DailyTask with _$DailyTask {
  const factory DailyTask({
    required String id,
    required String squadId,
    required String title,
    required String
    taskType, // 'stretch' | 'cardio' | 'night_run' | 'home_training'
    double? targetValue,
    String? targetUnit, // 'minutes' | 'reps' | 'km'
    @Default([]) List<int> recurringDays, // [1,2,3,4,5] = 周一到周五
    @Default(true) bool isActive,
    required DateTime createdAt,
  }) = _DailyTask;

  factory DailyTask.fromJson(Map<String, dynamic> json) =>
      _$DailyTaskFromJson(json);
}
