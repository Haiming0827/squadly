import 'package:freezed_annotation/freezed_annotation.dart';

part 'shared_expense.freezed.dart';
part 'shared_expense.g.dart';

/// 集体支出实体
@freezed
abstract class SharedExpense with _$SharedExpense {
  const factory SharedExpense({
    required String id,
    required String squadId,
    required String paidBy,
    required double amount,
    required String category, // 'dining' | 'transport' | 'entertainment' | 'other'
    String? description,
    required DateTime expenseDate,
    @Default(false) bool needsApproval,
    @Default(0) int approvedCount,
    required DateTime createdAt,
    // 关联信息
    String? paidByNickname,
  }) = _SharedExpense;

  factory SharedExpense.fromJson(Map<String, dynamic> json) =>
      _$SharedExpenseFromJson(json);
}
