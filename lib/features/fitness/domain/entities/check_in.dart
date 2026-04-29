import 'package:freezed_annotation/freezed_annotation.dart';

part 'check_in.freezed.dart';
part 'check_in.g.dart';

/// 打卡记录实体
@freezed
abstract class CheckIn with _$CheckIn {
  const factory CheckIn({
    required String id,
    required String taskId,
    required String userId,
    required String squadId,
    double? value,
    String? note,
    required DateTime checkedAt,
    required DateTime createdAt,
    // 关联信息
    String? userNickname,
    String? taskTitle,
  }) = _CheckIn;

  factory CheckIn.fromJson(Map<String, dynamic> json) =>
      _$CheckInFromJson(json);
}
