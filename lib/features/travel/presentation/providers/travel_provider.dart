import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/cloudbase_client_provider.dart';
import '../../../finance/domain/entities/public_fund.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../data/repositories/cloudbase_travel_repository.dart';
import '../../domain/entities/travel_plan.dart';
import '../../domain/repositories/travel_repository.dart';

final travelRepositoryProvider = Provider<TravelRepository>((ref) {
  final app = ref.watch(cloudBaseAppProvider);
  return CloudBaseTravelRepository(
    client: ref.watch(cloudBasePostgresClientProvider).rest,
    currentUserId: () async {
      final response = await app.auth.getSession();
      if (!response.isSuccess) return null;
      return response.data?.session?.user?.id;
    },
  );
});

final travelSnapshotProvider = FutureProvider.family<TravelSnapshot, String>((
  ref,
  squadId,
) async {
  final plans = await ref
      .watch(travelRepositoryProvider)
      .getSquadTravelPlans(squadId: squadId);
  final funds = await ref
      .watch(financeRepositoryProvider)
      .getSquadFunds(squadId: squadId);
  return TravelSnapshot(plans: _unwrap(plans), funds: _unwrap(funds));
});

T _unwrap<T>(Either<Failure, T> result) => result.fold(
  (failure) => throw StateError(switch (failure) {
    ServerFailure(:final message) => message,
    PermissionDeniedFailure() => '没有查看旅行数据的权限',
    UnauthorizedFailure() => '请先登录',
    NetworkFailure() => '网络连接失败，请稍后重试',
    _ => '旅行数据加载失败',
  }),
  (value) => value,
);

final class TravelSnapshot {
  const TravelSnapshot({required this.plans, required this.funds});

  final List<TravelPlan> plans;
  final List<PublicFund> funds;
}
