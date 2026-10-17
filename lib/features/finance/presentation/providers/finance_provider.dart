import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/cloudbase_client_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../squad/presentation/providers/squad_provider.dart';
import '../../data/repositories/cloudbase_finance_repository.dart';
import '../../domain/entities/private_asset.dart';
import '../../domain/entities/public_fund.dart';
import '../../domain/entities/shared_expense.dart';
import '../../domain/repositories/finance_repository.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  final app = ref.watch(cloudBaseAppProvider);
  return CloudBaseFinanceRepository(
    client: ref.watch(cloudBasePostgresClientProvider).rest,
    currentUserId: () async {
      final response = await app.auth.getSession();
      if (!response.isSuccess) return null;
      return response.data?.session?.user?.id;
    },
  );
});

final financeSnapshotProvider = FutureProvider.family<FinanceSnapshot, String>((
  ref,
  squadId,
) async {
  final repository = ref.watch(financeRepositoryProvider);
  final funds = await repository.getSquadFunds(squadId: squadId);
  final assets = await repository.getMyPrivateAssets();
  final expenses = await repository.getSquadExpenses(squadId: squadId);
  return FinanceSnapshot(
    funds: _value(funds),
    privateAssets: _value(assets),
    expenses: _value(expenses),
  );
});

final cloudBaseFinanceSquadProvider = Provider((ref) {
  ref.watch(authNotifierProvider);
  return ref.watch(currentSquadProvider);
});

T _value<T>(Either<Failure, T> result) => result.fold(
  (failure) => throw StateError(_financeFailureMessage(failure)),
  (value) => value,
);

String _financeFailureMessage(Failure failure) => switch (failure) {
  ServerFailure(:final message) => message,
  ValidationFailure(:final message) => message,
  UnauthorizedFailure() => '请先登录',
  PermissionDeniedFailure() => '没有查看理财数据的权限',
  NotFoundFailure() => '理财数据不存在',
  NetworkFailure() => '网络连接失败，请稍后重试',
  _ => '理财数据加载失败',
};

final class FinanceSnapshot {
  const FinanceSnapshot({
    required this.funds,
    required this.privateAssets,
    required this.expenses,
  });

  final List<PublicFund> funds;
  final List<PrivateAsset> privateAssets;
  final List<SharedExpense> expenses;
}
