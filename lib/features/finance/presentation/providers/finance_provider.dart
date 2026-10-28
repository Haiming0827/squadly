import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../app/providers/current_user_provider.dart';
import '../../../../app/providers/domain_repository_providers.dart';
import '../../../../app/providers/squad_context_providers.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/private_asset.dart';
import '../../domain/entities/public_fund.dart';
import '../../domain/entities/shared_expense.dart';

export '../../../../app/providers/domain_repository_providers.dart'
    show financeRepositoryProvider;

final canManagePublicFundsProvider = Provider.family<bool, String>((
  ref,
  squadId,
) {
  final userId = ref.watch(currentUserProvider).asData?.value?.id;
  if (userId == null) return false;
  final members = ref.watch(squadMembersProvider(squadId)).asData?.value;
  return members != null &&
      members.any(
        (member) => member.userId == userId && member.role == 'captain',
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

T _value<T>(Either<Failure, T> result) => result.fold(
  (failure) => throw StateError(financeFailureMessage(failure)),
  (value) => value,
);

String financeFailureMessage(Failure failure) => switch (failure) {
  ServerFailure() => '理财服务暂时不可用，请稍后重试',
  ValidationFailure(:final message) => message,
  UnauthorizedFailure() => '请先登录',
  PermissionDeniedFailure() => '没有执行此理财操作的权限',
  NotFoundFailure() => '理财数据不存在',
  NetworkFailure() => '网络连接失败，请稍后重试',
  _ => '理财数据暂时不可用，请稍后重试',
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
