// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SquadDto _$SquadDtoFromJson(Map<String, dynamic> json) => _SquadDto(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  inviteCode: json['invite_code'] as String,
  maxMembers: (json['max_members'] as num?)?.toInt() ?? 9,
  createdBy: json['created_by'] as String,
  createdAt: json['created_at'] as String,
);

Map<String, dynamic> _$SquadDtoToJson(_SquadDto instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'avatar_url': instance.avatarUrl,
  'invite_code': instance.inviteCode,
  'max_members': instance.maxMembers,
  'created_by': instance.createdBy,
  'created_at': instance.createdAt,
};
