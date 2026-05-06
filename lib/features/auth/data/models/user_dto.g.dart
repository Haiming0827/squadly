// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserDto _$UserDtoFromJson(Map<String, dynamic> json) => _UserDto(
  id: json['id'] as String,
  nickname: json['nickname'] as String,
  avatarUrl: json['avatar_url'] as String?,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  createdAt: json['created_at'] as String,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$UserDtoToJson(_UserDto instance) => <String, dynamic>{
  'id': instance.id,
  'nickname': instance.nickname,
  'avatar_url': instance.avatarUrl,
  'phone': instance.phone,
  'email': instance.email,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};
