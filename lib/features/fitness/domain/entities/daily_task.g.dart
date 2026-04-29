// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DailyTask _$DailyTaskFromJson(Map<String, dynamic> json) => _DailyTask(
  id: json['id'] as String,
  squadId: json['squadId'] as String,
  title: json['title'] as String,
  taskType: json['taskType'] as String,
  targetValue: (json['targetValue'] as num?)?.toDouble(),
  targetUnit: json['targetUnit'] as String?,
  recurringDays:
      (json['recurringDays'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  isActive: json['isActive'] as bool? ?? true,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$DailyTaskToJson(_DailyTask instance) =>
    <String, dynamic>{
      'id': instance.id,
      'squadId': instance.squadId,
      'title': instance.title,
      'taskType': instance.taskType,
      'targetValue': instance.targetValue,
      'targetUnit': instance.targetUnit,
      'recurringDays': instance.recurringDays,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
    };
