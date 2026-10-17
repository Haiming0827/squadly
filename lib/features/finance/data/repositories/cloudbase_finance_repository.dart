import 'package:fpdart/fpdart.dart';
import 'package:postgrest/postgrest.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/fund_transaction.dart';
import '../../domain/entities/private_asset.dart';
import '../../domain/entities/public_fund.dart';
import '../../domain/entities/shared_expense.dart';
import '../../domain/repositories/finance_repository.dart';

typedef CurrentFinanceUserId = Future<String?> Function();

/// Finance adapter for CloudBase PostgreSQL. Private asset queries always
/// include the current owner ID; PostgreSQL RLS remains the security boundary.
final class CloudBaseFinanceRepository implements FinanceRepository {
  const CloudBaseFinanceRepository({
    required PostgrestClient client,
    required CurrentFinanceUserId currentUserId,
  }) : _client = client,
       _currentUserId = currentUserId;

  final PostgrestClient _client;
  final CurrentFinanceUserId _currentUserId;

  @override
  Future<Either<Failure, PublicFund>> createFund({
    required String squadId,
    required String name,
    required String fundType,
    double targetAmount = 0,
  }) => _capture(() async {
    final userId = await _requireUserId();
    final row = await _client
        .from('public_funds')
        .insert({
          'squad_id': squadId,
          'name': name.trim(),
          'fund_type': fundType,
          'target_amount': targetAmount,
          'created_by': userId,
        })
        .select()
        .single();
    return _fund(row);
  });

  @override
  Future<Either<Failure, List<PublicFund>>> getSquadFunds({
    required String squadId,
  }) => _capture(() async {
    final rows = await _client
        .from('public_funds')
        .select()
        .eq('squad_id', squadId)
        .order('created_at');
    return (rows as List)
        .map((row) => _fund(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  });

  @override
  Future<Either<Failure, FundTransaction>> addFundTransaction({
    required String fundId,
    required double amount,
    String? description,
  }) => _capture(() async {
    final userId = await _requireUserId();
    final row = await _client
        .from('fund_transactions')
        .insert({
          'fund_id': fundId,
          'user_id': userId,
          'amount': amount,
          'description': _nullableText(description),
        })
        .select()
        .single();
    return _transaction(row);
  });

  @override
  Future<Either<Failure, List<FundTransaction>>> getFundTransactions({
    required String fundId,
  }) => _capture(() async {
    final rows = await _client
        .from('fund_transactions')
        .select()
        .eq('fund_id', fundId)
        .order('transaction_date', ascending: false);
    return (rows as List)
        .map((row) => _transaction(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  });

  @override
  Future<Either<Failure, double>> getFundBalance({required String fundId}) =>
      _capture(() async {
        final row = await _client
            .from('public_funds')
            .select('current_amount')
            .eq('id', fundId)
            .single();
        return _number(row['current_amount']);
      });

  @override
  Future<Either<Failure, PrivateAsset>> createPrivateAsset({
    required String assetType,
    required String name,
    double amount = 0,
    String? note,
  }) => _capture(() async {
    final userId = await _requireUserId();
    final row = await _client
        .from('private_assets')
        .insert({
          'user_id': userId,
          'asset_type': assetType,
          'name': name.trim(),
          'amount': amount,
          'note': _nullableText(note),
        })
        .select()
        .single();
    return _privateAsset(row);
  });

  @override
  Future<Either<Failure, List<PrivateAsset>>> getMyPrivateAssets() =>
      _capture(() async {
        final userId = await _requireUserId();
        final rows = await _client
            .from('private_assets')
            .select()
            .eq('user_id', userId)
            .order('updated_at', ascending: false);
        return (rows as List)
            .map((row) => _privateAsset(Map<String, dynamic>.from(row as Map)))
            .toList(growable: false);
      });

  @override
  Future<Either<Failure, PrivateAsset>> updatePrivateAsset({
    required String assetId,
    String? name,
    double? amount,
    String? note,
  }) => _capture(() async {
    final userId = await _requireUserId();
    final changes = <String, Object?>{};
    if (name != null) changes['name'] = name.trim();
    if (amount != null) changes['amount'] = amount;
    if (note != null) changes['note'] = _nullableText(note);
    final row = await _client
        .from('private_assets')
        .update(changes)
        .eq('id', assetId)
        .eq('user_id', userId)
        .select()
        .single();
    return _privateAsset(row);
  });

  @override
  Future<Either<Failure, Unit>> deletePrivateAsset({required String assetId}) =>
      _capture(() async {
        final userId = await _requireUserId();
        await _client
            .from('private_assets')
            .delete()
            .eq('id', assetId)
            .eq('user_id', userId);
        return unit;
      });

  @override
  Future<Either<Failure, SharedExpense>> recordSharedExpense({
    required String squadId,
    required double amount,
    required String category,
    String? description,
    bool needsApproval = false,
  }) => _capture(() async {
    final userId = await _requireUserId();
    final row = await _client
        .from('shared_expenses')
        .insert({
          'squad_id': squadId,
          'paid_by': userId,
          'amount': amount,
          'category': category,
          'description': _nullableText(description),
          'needs_approval': needsApproval,
        })
        .select()
        .single();
    return _expense(row);
  });

  @override
  Future<Either<Failure, List<SharedExpense>>> getSquadExpenses({
    required String squadId,
    DateTime? from,
    DateTime? to,
  }) => _capture(() async {
    var query = _client
        .from('shared_expenses')
        .select()
        .eq('squad_id', squadId);
    if (from case final date?) query = query.gte('expense_date', _date(date));
    if (to case final date?) query = query.lte('expense_date', _date(date));
    final rows = await query.order('expense_date', ascending: false);
    return (rows as List)
        .map((row) => _expense(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  });

  Future<String> _requireUserId() async {
    final id = await _currentUserId();
    if (id == null || id.isEmpty) throw const _Unauthenticated();
    return id;
  }

  Future<Either<Failure, T>> _capture<T>(Future<T> Function() operation) async {
    try {
      return right(await operation());
    } on _Unauthenticated {
      return left(const Failure.unauthorized());
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        return left(const Failure.permissionDenied());
      }
      if (error.code == 'PGRST116') {
        return left(const Failure.notFound());
      }
      return left(const Failure.server(message: '理财数据操作失败'));
    } catch (_) {
      return left(const Failure.network(message: '无法连接理财服务'));
    }
  }

  PublicFund _fund(Map<String, dynamic> row) => PublicFund(
    id: row['id'] as String,
    squadId: row['squad_id'] as String,
    name: row['name'] as String,
    fundType: row['fund_type'] as String,
    targetAmount: _number(row['target_amount']),
    currentAmount: _number(row['current_amount']),
    createdBy: row['created_by'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  FundTransaction _transaction(Map<String, dynamic> row) => FundTransaction(
    id: row['id'] as String,
    fundId: row['fund_id'] as String,
    userId: row['user_id'] as String,
    amount: _number(row['amount']),
    description: row['description'] as String?,
    approvedBy: row['approved_by'] as String?,
    transactionDate: DateTime.parse(row['transaction_date'] as String),
  );

  PrivateAsset _privateAsset(Map<String, dynamic> row) => PrivateAsset(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    assetType: row['asset_type'] as String,
    name: row['name'] as String,
    amount: _number(row['amount']),
    note: row['note'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );

  SharedExpense _expense(Map<String, dynamic> row) => SharedExpense(
    id: row['id'] as String,
    squadId: row['squad_id'] as String,
    paidBy: row['paid_by'] as String,
    amount: _number(row['amount']),
    category: row['category'] as String,
    description: row['description'] as String?,
    expenseDate: DateTime.parse(row['expense_date'] as String),
    needsApproval: row['needs_approval'] as bool? ?? false,
    approvedCount: row['approved_count'] as int? ?? 0,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

double _number(Object? value) => (value as num?)?.toDouble() ?? 0;
String? _nullableText(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();
String _date(DateTime value) => value.toIso8601String().split('T').first;

final class _Unauthenticated implements Exception {
  const _Unauthenticated();
}
