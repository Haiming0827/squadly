import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/squad_remote_datasource.dart';
import '../../data/repositories/squad_repository_impl.dart';
import '../../domain/entities/squad.dart';
import '../../domain/entities/squad_member.dart';
import '../../domain/repositories/squad_repository.dart';

final squadRepositoryProvider = Provider<SquadRepository>((ref) {
  return SquadRepositoryImpl(
    SquadRemoteDatasource(ref.watch(supabaseClientProvider)),
  );
});

final selectedSquadIdProvider = StateProvider<String?>((ref) => null);

final mySquadsProvider = FutureProvider<List<Squad>>((ref) async {
  ref.watch(authNotifierProvider);
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
  final result = await ref
      .watch(squadRepositoryProvider)
      .getSquadMembers(squadId: squadId);
  return result.fold(
    (failure) => throw StateError(squadFailureMessage(failure)),
    (members) => members,
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
