import 'package:freezed_annotation/freezed_annotation.dart';

part 'squad.freezed.dart';
part 'squad.g.dart';

/// 小队实体
@freezed
abstract class Squad with _$Squad {
  const factory Squad({
    required String id,
    required String name,
    String? description,
    String? avatarUrl,
    required String inviteCode,
    @Default(9) int maxMembers,
    required String createdBy,
    required DateTime createdAt,
  }) = _Squad;

  factory Squad.fromJson(Map<String, dynamic> json) => _$SquadFromJson(json);
}
