import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/cloudbase_client_provider.dart';
import '../../features/conversation/data/cached_conversation_repository.dart';
import '../../features/conversation/data/cloudbase_conversation_repository.dart';
import '../../features/conversation/domain/conversation_repository.dart';
import '../../features/finance/data/repositories/cloudbase_finance_repository.dart';
import '../../features/finance/domain/repositories/finance_repository.dart';
import '../../features/fitness/data/repositories/cloudbase_fitness_repository.dart';
import '../../features/fitness/domain/repositories/fitness_repository.dart';
import '../../features/food/data/repositories/cloudbase_food_repository.dart';
import '../../features/food/domain/repositories/food_repository.dart';
import '../../features/plan/data/repositories/cloudbase_plan_repository.dart';
import '../../features/plan/data/repositories/demo_plan_repository.dart';
import '../../features/plan/domain/repositories/plan_repository.dart';
import '../../features/social/data/cloudbase_social_repository.dart';
import '../../features/social/domain/repositories/social_repository.dart';
import '../../features/squad/data/datasources/cloudbase_squad_remote_datasource.dart';
import '../../features/squad/data/repositories/squad_repository_impl.dart';
import '../../features/squad/domain/repositories/squad_repository.dart';
import '../../features/travel/data/repositories/cloudbase_travel_repository.dart';
import '../../features/travel/domain/repositories/travel_repository.dart';
import '../demo/demo_store.dart';
import 'account_postgres_provider.dart';
import 'conversation_cache_provider.dart';
import 'current_user_provider.dart';
import 'offline_access_provider.dart';

/// Application composition root for feature domain repository interfaces.
///
/// Feature presentation providers may consume these bindings, but should not
/// import repository providers from another feature's presentation layer.
final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  if (ref.watch(cloudBaseConfigProvider).useDemo) {
    throw StateError(
      'Conversation remote repository is unavailable in demo mode',
    );
  }
  final remote = CloudBaseConversationRepository(
    ref.watch(accountPostgresClientProvider).rest,
  );
  final userId = ref.watch(currentUserProvider).asData?.value?.id ?? '';
  final cache = ref.watch(conversationCacheProvider);
  if (cache == null) return remote;
  return CachedConversationRepository(
    remote: remote,
    cache: cache,
    userId: userId,
    canReadCache: () {
      if (!ref.mounted) return false;
      final access = ref.read(offlineAccessProvider);
      return access.canReadAt(DateTime.now()) &&
          access.session?.userId == userId;
    },
    isCurrentAccount: () =>
        ref.mounted &&
        userId.isNotEmpty &&
        ref.read(currentUserProvider).asData?.value?.id == userId,
  );
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return CloudBaseFinanceRepository(
    client: ref.watch(accountPostgresClientProvider).rest,
    currentUserId: () => _currentUserId(ref),
  );
});

final fitnessRepositoryProvider = Provider<FitnessRepository>((ref) {
  return CloudBaseFitnessRepository(
    client: ref.watch(accountPostgresClientProvider).rest,
    currentUserId: () => _currentUserId(ref),
  );
});

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return CloudBaseFoodRepository(
    client: ref.watch(accountPostgresClientProvider).rest,
    currentUserId: () => _currentUserId(ref),
  );
});

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  if (ref.watch(useDemoBackendProvider)) {
    return DemoPlanRepository(ref.watch(demoAppStoreProvider.notifier));
  }
  return CloudBasePlanRepository(
    client: ref.watch(accountPostgresClientProvider).rest,
    currentUserId: () => _currentUserId(ref),
  );
});

final squadRepositoryProvider = Provider<SquadRepository>((ref) {
  return SquadRepositoryImpl(
    CloudBaseSquadRemoteDatasource(
      ref.watch(accountPostgresClientProvider).rest,
    ),
  );
});

final travelRepositoryProvider = Provider<TravelRepository>((ref) {
  return CloudBaseTravelRepository(
    client: ref.watch(accountPostgresClientProvider).rest,
    currentUserId: () => _currentUserId(ref),
  );
});

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  if (ref.watch(useDemoBackendProvider)) {
    throw StateError('CloudBase Social repository is unavailable in demo mode');
  }
  return CloudBaseSocialRepository(
    client: ref.watch(accountPostgresClientProvider).rest,
    currentUserId: () => _currentUserId(ref),
  );
});

Future<String?> _currentUserId(Ref ref) async {
  final response = await ref.read(cloudBaseAppProvider).auth.getSession();
  if (!response.isSuccess) return null;
  return response.data?.session?.user?.id;
}
