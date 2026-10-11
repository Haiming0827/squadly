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
