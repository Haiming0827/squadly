// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad_member_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SquadMemberDto _$SquadMemberDtoFromJson(Map<String, dynamic> json) =>
    _SquadMemberDto(
      id: json['id'] as String,
      squadId: json['squad_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      joinedAt: json['joined_at'] as String,
      profiles: json['profiles'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$SquadMemberDtoToJson(_SquadMemberDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'squad_id': instance.squadId,
      'user_id': instance.userId,
      'role': instance.role,
      'joined_at': instance.joinedAt,
      'profiles': instance.profiles,
    };
