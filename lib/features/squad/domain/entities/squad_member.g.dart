// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SquadMember _$SquadMemberFromJson(Map<String, dynamic> json) => _SquadMember(
  id: json['id'] as String,
  squadId: json['squadId'] as String,
  userId: json['userId'] as String,
  role: json['role'] as String,
  joinedAt: DateTime.parse(json['joinedAt'] as String),
  nickname: json['nickname'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
);

Map<String, dynamic> _$SquadMemberToJson(_SquadMember instance) =>
    <String, dynamic>{
      'id': instance.id,
      'squadId': instance.squadId,
      'userId': instance.userId,
      'role': instance.role,
      'joinedAt': instance.joinedAt.toIso8601String(),
      'nickname': instance.nickname,
      'avatarUrl': instance.avatarUrl,
    };
