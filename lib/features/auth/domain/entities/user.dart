import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// 用户实体
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String nickname,
    String? avatarUrl,
    String? phone,
    String? email,
    required DateTime createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
