import 'package:freezed_annotation/freezed_annotation.dart';

part 'squad_member_dto.freezed.dart';
part 'squad_member_dto.g.dart';

/// 小队成员 DTO（对应 Supabase squad_members 表 + join profiles）
@freezed
abstract class SquadMemberDto with _$SquadMemberDto {
  const factory SquadMemberDto({
    required String id,
    @JsonKey(name: 'squad_id') required String squadId,
    @JsonKey(name: 'user_id') required String userId,
    required String role,
    @JsonKey(name: 'joined_at') required String joinedAt,
    // join profiles 时的嵌套数据
    Map<String, dynamic>? profiles,
  }) = _SquadMemberDto;

  factory SquadMemberDto.fromJson(Map<String, dynamic> json) =>
      _$SquadMemberDtoFromJson(json);
}
