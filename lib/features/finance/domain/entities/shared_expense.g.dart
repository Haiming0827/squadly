// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shared_expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SharedExpense _$SharedExpenseFromJson(Map<String, dynamic> json) =>
    _SharedExpense(
      id: json['id'] as String,
      squadId: json['squadId'] as String,
      paidBy: json['paidBy'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      description: json['description'] as String?,
      expenseDate: DateTime.parse(json['expenseDate'] as String),
      needsApproval: json['needsApproval'] as bool? ?? false,
      approvedCount: (json['approvedCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      paidByNickname: json['paidByNickname'] as String?,
    );

Map<String, dynamic> _$SharedExpenseToJson(_SharedExpense instance) =>
    <String, dynamic>{
      'id': instance.id,
      'squadId': instance.squadId,
      'paidBy': instance.paidBy,
      'amount': instance.amount,
      'category': instance.category,
      'description': instance.description,
      'expenseDate': instance.expenseDate.toIso8601String(),
      'needsApproval': instance.needsApproval,
      'approvedCount': instance.approvedCount,
      'createdAt': instance.createdAt.toIso8601String(),
      'paidByNickname': instance.paidByNickname,
    };
