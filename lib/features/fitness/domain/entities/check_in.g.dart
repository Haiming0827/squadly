// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_in.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CheckIn _$CheckInFromJson(Map<String, dynamic> json) => _CheckIn(
  id: json['id'] as String,
  taskId: json['taskId'] as String,
  userId: json['userId'] as String,
  squadId: json['squadId'] as String,
  value: (json['value'] as num?)?.toDouble(),
  note: json['note'] as String?,
  checkedAt: DateTime.parse(json['checkedAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  userNickname: json['userNickname'] as String?,
  taskTitle: json['taskTitle'] as String?,
);

Map<String, dynamic> _$CheckInToJson(_CheckIn instance) => <String, dynamic>{
  'id': instance.id,
  'taskId': instance.taskId,
  'userId': instance.userId,
  'squadId': instance.squadId,
  'value': instance.value,
  'note': instance.note,
  'checkedAt': instance.checkedAt.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'userNickname': instance.userNickname,
  'taskTitle': instance.taskTitle,
};
