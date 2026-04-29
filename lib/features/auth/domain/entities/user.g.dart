// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['id'] as String,
  nickname: json['nickname'] as String,
  avatarUrl: json['avatarUrl'] as String?,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'nickname': instance.nickname,
  'avatarUrl': instance.avatarUrl,
  'phone': instance.phone,
  'email': instance.email,
  'createdAt': instance.createdAt.toIso8601String(),
};
