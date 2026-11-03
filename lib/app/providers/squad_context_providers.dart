import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/error/failures.dart';
import '../../features/squad/domain/entities/squad.dart';
import '../../features/squad/domain/entities/squad_member.dart';
import '../../features/squad/domain/entities/squad_recent_share.dart';
import '../../features/squad/domain/usecases/get_squad_recent_shares.dart';
import 'current_user_provider.dart';
import 'domain_repository_providers.dart';

/// App-wide active Squad context shared by feature presentations.
final selectedSquadIdProvider = StateProvider<String?>((ref) => null);

final mySquadsProvider = FutureProvider<List<Squad>>((ref) async {
  ref.watch(currentUserProvider);
  final result = await ref.watch(squadRepositoryProvider).getMySquads();
  return result.fold(
    (failure) => throw StateError(squadFailureMessage(failure)),
    (squads) => squads,
  );
});

final currentSquadProvider = Provider<AsyncValue<Squad?>>((ref) {
  final selectedId = ref.watch(selectedSquadIdProvider);
  return ref.watch(mySquadsProvider).whenData((squads) {
    if (squads.isEmpty) return null;
    for (final squad in squads) {
      if (squad.id == selectedId) return squad;
    }
    return squads.first;
  });
});

final squadMembersProvider = FutureProvider.family<List<SquadMember>, String>((
  ref,
  squadId,
) async {
  ref.watch(currentUserProvider);
  final result = await ref
      .watch(squadRepositoryProvider)
      .getSquadMembers(squadId: squadId);
  return result.fold(
    (failure) => throw StateError(squadFailureMessage(failure)),
    (members) => members,
  );
});

final squadRecentSharesProvider =
    FutureProvider.family<List<SquadRecentShare>, String>((ref, squadId) async {
      ref.watch(currentUserProvider);
      final result = await GetSquadRecentShares(
        ref.watch(conversationRepositoryProvider),
      )(squadId: squadId);
      return result.fold(
        (failure) => throw StateError(squadFailureMessage(failure)),
        (shares) => shares,
      );
    });

String squadFailureMessage(Failure failure) => switch (failure) {
  ServerFailure(:final message) => message,
  ValidationFailure(:final message) => message,
  SquadFullFailure() => '小队已满员',
  SquadMinMembersFailure() => '小队至少需要 2 人',
  UnauthorizedFailure() => '请先登录',
  PermissionDeniedFailure() => '没有操作权限',
  NetworkFailure() => '网络连接失败，请稍后重试',
  NotFoundFailure() => '没有找到对应的小队',
  UnknownFailure() => '操作失败，请稍后重试',
};
