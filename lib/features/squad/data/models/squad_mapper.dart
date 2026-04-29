import '../../domain/entities/squad.dart';
import '../../domain/entities/squad_member.dart';
import 'squad_dto.dart';
import 'squad_member_dto.dart';

extension SquadDtoMapper on SquadDto {
  Squad toEntity() {
    return Squad(
      id: id,
      name: name,
      description: description,
      avatarUrl: avatarUrl,
      inviteCode: inviteCode,
      maxMembers: maxMembers,
      createdBy: createdBy,
      createdAt: DateTime.parse(createdAt),
    );
  }
}

extension SquadMemberDtoMapper on SquadMemberDto {
  SquadMember toEntity() {
    return SquadMember(
      id: id,
      squadId: squadId,
      userId: userId,
      role: role,
      joinedAt: DateTime.parse(joinedAt),
      nickname: profiles?['nickname'] as String?,
      avatarUrl: profiles?['avatar_url'] as String?,
    );
  }
}
