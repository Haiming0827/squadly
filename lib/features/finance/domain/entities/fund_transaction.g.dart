// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fund_transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FundTransaction _$FundTransactionFromJson(Map<String, dynamic> json) =>
    _FundTransaction(
      id: json['id'] as String,
      fundId: json['fundId'] as String,
      userId: json['userId'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      approvedBy: json['approvedBy'] as String?,
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      userNickname: json['userNickname'] as String?,
    );

Map<String, dynamic> _$FundTransactionToJson(_FundTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fundId': instance.fundId,
      'userId': instance.userId,
      'amount': instance.amount,
      'description': instance.description,
      'approvedBy': instance.approvedBy,
      'transactionDate': instance.transactionDate.toIso8601String(),
      'userNickname': instance.userNickname,
    };
