import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/conversation/presentation/offline_conversation_controller.dart';
import 'conversation_cache_provider.dart';
import 'offline_access_provider.dart';

final requireOnlineLoginProvider = Provider<void Function()>(
  (ref) =>
      () => ref.read(authNotifierProvider.notifier).requireOnlineLogin(),
);

final offlineConversationProvider =
    StateNotifierProvider.autoDispose<
      OfflineConversationController,
      OfflineConversationState
    >((ref) {
      final userId = ref.watch(
        offlineAccessProvider.select(
          (state) =>
              state.canReadAt(DateTime.now()) ? state.session?.userId : null,
        ),
      );
      final controller = OfflineConversationController(
        cache: userId == null ? null : ref.watch(conversationCacheProvider),
        userId: userId ?? '',
        canRead: () =>
            ref.mounted &&
            ref.read(offlineAccessProvider).canReadAt(DateTime.now()) &&
            ref.read(offlineAccessProvider).session?.userId == userId,
      );
      Future.microtask(() {
        if (ref.mounted) unawaited(controller.initialize());
      });
      return controller;
    });
