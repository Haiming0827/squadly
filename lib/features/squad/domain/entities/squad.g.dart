// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Squad _$SquadFromJson(Map<String, dynamic> json) => _Squad(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  inviteCode: json['inviteCode'] as String,
  maxMembers: (json['maxMembers'] as num?)?.toInt() ?? 9,
  createdBy: json['createdBy'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$SquadToJson(_Squad instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'avatarUrl': instance.avatarUrl,
  'inviteCode': instance.inviteCode,
  'maxMembers': instance.maxMembers,
  'createdBy': instance.createdBy,
  'createdAt': instance.createdAt.toIso8601String(),
};
