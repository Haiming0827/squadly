import 'package:freezed_annotation/freezed_annotation.dart';

part 'fund_transaction.freezed.dart';
part 'fund_transaction.g.dart';

/// 基金流水实体
@freezed
abstract class FundTransaction with _$FundTransaction {
  const factory FundTransaction({
    required String id,
    required String fundId,
    required String userId,
    required double amount, // 正数存入，负数支出
    String? description,
    String? approvedBy,
    required DateTime transactionDate,
    // 关联信息
    String? userNickname,
  }) = _FundTransaction;

  factory FundTransaction.fromJson(Map<String, dynamic> json) =>
      _$FundTransactionFromJson(json);
}
