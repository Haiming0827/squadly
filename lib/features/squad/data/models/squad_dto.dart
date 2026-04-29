import 'package:freezed_annotation/freezed_annotation.dart';

part 'squad_dto.freezed.dart';
part 'squad_dto.g.dart';

/// 小队 DTO（对应 Supabase squads 表）
@freezed
abstract class SquadDto with _$SquadDto {
  const factory SquadDto({
    required String id,
    required String name,
    String? description,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'invite_code') required String inviteCode,
    @JsonKey(name: 'max_members') @Default(9) int maxMembers,
    @JsonKey(name: 'created_by') required String createdBy,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _SquadDto;

  factory SquadDto.fromJson(Map<String, dynamic> json) =>
      _$SquadDtoFromJson(json);
}
