import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/cloudbase_client_provider.dart';
import '../../features/conversation/data/cloudbase_conversation_customization.dart';
import '../../features/conversation/domain/conversation_preference.dart';
import '../../features/squad/data/cloudbase_squad_profile_repository.dart';
import '../../features/squad/data/squad_avatar_picker.dart';
import '../../features/squad/domain/entities/squad.dart';
import '../../features/squad/domain/entities/squad_member.dart';
import '../../features/squad/domain/repositories/squad_profile_repository.dart';
import '../demo/demo_conversation_customization.dart';
import '../demo/demo_store.dart';
import 'account_postgres_provider.dart';
import 'current_user_provider.dart';
import 'photo_providers.dart';
import 'squad_context_providers.dart';

final customizationUserIdProvider = Provider<String?>((ref) {
  if (ref.watch(useDemoBackendProvider)) {
    return ref.watch(
      demoAppStoreProvider.select((state) => state.currentUser?.id),
    );
  }
  return ref.watch(currentUserProvider).asData?.value?.id;
});
final conversationCustomizationRepositoryProvider =
    Provider<ConversationCustomizationRepository>((ref) {
      final userId = ref.watch(customizationUserIdProvider);
      if (ref.watch(useDemoBackendProvider)) {
        return DemoConversationCustomization(
          ref.watch(demoAppStoreProvider.notifier),
          userId ?? '',
        );
      }
      return CloudBaseConversationCustomization(
        ref.watch(accountPostgresClientProvider).rest,
      );
    });
final conversationPreferencesProvider =
    FutureProvider<List<ConversationPreference>>((ref) async {
      if (ref.watch(customizationUserIdProvider) == null) return const [];
      final result = await ref
          .watch(conversationCustomizationRepositoryProvider)
          .load();
      return result.fold(
        (failure) => throw StateError(squadFailureMessage(failure)),
        (values) => values,
      );
    });
final conversationPreferenceMapProvider =
    Provider<Map<String, ConversationPreference>>((ref) {
      return {
        for (final pref
            in ref.watch(conversationPreferencesProvider).asData?.value ??
                <ConversationPreference>[])
          pref.squadId: pref,
      };
    });
final squadProfileRepositoryProvider = Provider<SquadProfileRepository>((ref) {
  if (ref.watch(useDemoBackendProvider)) {
    return DemoSquadProfileRepository(ref.watch(demoAppStoreProvider.notifier));
  }
  return CloudBaseSquadProfileRepository(
    ref.watch(accountPostgresClientProvider).rest,
  );
});
final squadAvatarPickerProvider = Provider<SquadAvatarPicker>(
  (ref) => PreparedSquadAvatarPicker(ref.watch(photoSourceProvider)),
);
final settingsSquadProvider = FutureProvider.family<Squad?, String>((
  ref,
  squadId,
) async {
  final squads = ref.watch(useDemoBackendProvider)
      ? ref.watch(demoAppStoreProvider).mySquads
      : await ref.watch(mySquadsProvider.future);
  return squads.where((s) => s.id == squadId).firstOrNull;
});
final settingsMembersProvider =
    FutureProvider.family<List<SquadMember>, String>((ref, squadId) async {
      ref.watch(customizationUserIdProvider);
      if (ref.watch(useDemoBackendProvider)) {
        return ref.watch(demoAppStoreProvider).membersFor(squadId);
      }
      return ref.watch(squadMembersProvider(squadId).future);
    });

Future<void> recordConversationOpen(WidgetRef ref, String squadId) async {
  final owner = ref.read(customizationUserIdProvider);
  await ref
      .read(conversationCustomizationRepositoryProvider)
      .recordOpen(squadId);
  if (ref.context.mounted && ref.read(customizationUserIdProvider) == owner) {
    ref.invalidate(conversationPreferencesProvider);
  }
}
