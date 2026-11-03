import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../../core/network/cloudbase_client_provider.dart';
import '../../features/auth/data/repositories/personal_avatar_repository.dart';
import '../../features/auth/domain/repositories/personal_avatar_repository.dart';
import '../../features/squad/domain/entities/squad.dart';
import '../../features/squad/domain/squad_avatar_format.dart';
import '../demo/demo_store.dart';
import 'account_postgres_provider.dart';
import 'current_user_provider.dart';
import 'squad_context_providers.dart';

final personalHomeSquadsProvider = FutureProvider<List<Squad>>((ref) async {
  if (ref.watch(useDemoBackendProvider)) {
    return ref.watch(demoAppStoreProvider).mySquads;
  }
  final owner = ref.watch(currentUserProvider).asData?.value?.id;
  if (owner == null) return const [];
  return ref.watch(mySquadsProvider.future);
});
final personalAvatarAvailableProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
);
final personalAvatarRepositoryProvider = Provider<PersonalAvatarRepository>((
  ref,
) {
  final owner = ref.watch(currentUserProvider).asData?.value?.id ?? '';
  if (ref.watch(useDemoBackendProvider)) {
    return _DemoPersonalAvatar(ref.watch(demoAppStoreProvider.notifier), owner);
  }
  return CloudBasePersonalAvatarRepository(
    ref.watch(accountPostgresClientProvider).rest,
    owner,
  );
});

final class _DemoPersonalAvatar implements PersonalAvatarRepository {
  const _DemoPersonalAvatar(this.store, this.owner);
  final DemoAppStore store;
  final String owner;
  @override
  Future<Either<Failure, void>> save(String? avatar) async {
    if (owner.isEmpty || store.getCurrentUser()?.id != owner) {
      return left(const Failure.unauthorized());
    }
    if (avatar != null && decodeSquadAvatar(avatar) == null) {
      return left(const Failure.validation(message: '请重新选择头像'));
    }
    store.updateAvatar(avatar);
    return right(null);
  }
}
