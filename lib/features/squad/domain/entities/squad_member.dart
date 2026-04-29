import 'package:freezed_annotation/freezed_annotation.dart';

part 'squad_member.freezed.dart';
part 'squad_member.g.dart';

/// 小队成员实体
@freezed
abstract class SquadMember with _$SquadMember {
  const factory SquadMember({
    required String id,
    required String squadId,
    required String userId,
    required String role, // 'captain' | 'member'
    required DateTime joinedAt,
    // 关联用户信息（查询时 join）
    String? nickname,
    String? avatarUrl,
  }) = _SquadMember;

  factory SquadMember.fromJson(Map<String, dynamic> json) =>
      _$SquadMemberFromJson(json);
}
