import '../../domain/entities/user.dart';
import '../models/user_dto.dart';

/// UserDto → User 实体映射
extension UserDtoMapper on UserDto {
  User toEntity() {
    return User(
      id: id,
      nickname: nickname,
      avatarUrl: avatarUrl,
      phone: phone,
      email: email,
      createdAt: DateTime.parse(createdAt),
    );
  }
}

/// User 实体 → 用于创建 profile 的 Map
extension UserToMap on User {
  Map<String, dynamic> toProfileInsert() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'phone': phone,
    };
  }
}
