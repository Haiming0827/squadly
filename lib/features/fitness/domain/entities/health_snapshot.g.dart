// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HealthSnapshot _$HealthSnapshotFromJson(Map<String, dynamic> json) =>
    _HealthSnapshot(
      id: json['id'] as String,
      userId: json['userId'] as String,
      squadId: json['squadId'] as String,
      weight: (json['weight'] as num?)?.toDouble(),
      workoutMinutes: (json['workoutMinutes'] as num?)?.toInt(),
      caloriesBurned: (json['caloriesBurned'] as num?)?.toInt(),
      recordedDate: DateTime.parse(json['recordedDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$HealthSnapshotToJson(_HealthSnapshot instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'squadId': instance.squadId,
      'weight': instance.weight,
      'workoutMinutes': instance.workoutMinutes,
      'caloriesBurned': instance.caloriesBurned,
      'recordedDate': instance.recordedDate.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };
