import 'package:freezed_annotation/freezed_annotation.dart';

part 'health_snapshot.freezed.dart';
part 'health_snapshot.g.dart';

/// 健康数据快照实体
@freezed
abstract class HealthSnapshot with _$HealthSnapshot {
  const factory HealthSnapshot({
    required String id,
    required String userId,
    required String squadId,
    double? weight,
    int? workoutMinutes,
    int? caloriesBurned,
    required DateTime recordedDate,
    required DateTime createdAt,
  }) = _HealthSnapshot;

  factory HealthSnapshot.fromJson(Map<String, dynamic> json) =>
      _$HealthSnapshotFromJson(json);
}
