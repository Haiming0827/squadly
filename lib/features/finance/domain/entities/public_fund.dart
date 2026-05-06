import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_fund.freezed.dart';
part 'public_fund.g.dart';

/// 公共基金实体
@freezed
abstract class PublicFund with _$PublicFund {
  const factory PublicFund({
    required String id,
    required String squadId,
    required String name,
    required String
    fundType, // 'travel' | 'dining' | 'team_building' | 'custom'
    @Default(0) double targetAmount,
    @Default(0) double currentAmount,
    required String createdBy,
    required DateTime createdAt,
  }) = _PublicFund;

  factory PublicFund.fromJson(Map<String, dynamic> json) =>
      _$PublicFundFromJson(json);
}
