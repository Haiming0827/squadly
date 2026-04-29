import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_plan.freezed.dart';
part 'workout_plan.g.dart';

/// 训练计划实体
@freezed
abstract class WorkoutPlan with _$WorkoutPlan {
  const factory WorkoutPlan({
    required String id,
    required String squadId,
    required String name,
    required String planType, // 'muscle_gain' | 'fat_loss' | 'body_shaping' | 'custom'
    String? description,
    required String createdBy,
    required DateTime createdAt,
  }) = _WorkoutPlan;

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) =>
      _$WorkoutPlanFromJson(json);
}
