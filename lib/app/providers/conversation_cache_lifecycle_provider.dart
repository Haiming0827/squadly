import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/conversation/domain/conversation_cache.dart';

import 'conversation_cache_provider.dart';
import 'current_user_provider.dart';
import 'offline_access_provider.dart';

final conversationCacheLifecycleProvider = Provider<void>((ref) {
  var confirmedId = ref.read(currentUserProvider).asData?.value?.id;
  String? cleanedForUser;
  void accept(String? nextId) {
    final cache = ref.read(conversationCacheProvider);
    if (confirmedId != null && confirmedId != nextId) {
      unawaited(
        cache
                ?.clearUser(confirmedId!, suspend: true)
                .catchError((Object _) {}) ??
            Future.value(),
      );
    }
    if (nextId != null && confirmedId != nextId) cache?.resumeUser(nextId);
    confirmedId = nextId;
  }

  ref.listen(currentUserProvider, (previous, next) {
    if (next is AsyncLoading) {
      ref.read(offlineAccessProvider.notifier).pauseForAuthentication();
      return;
    }
    if (previous is AsyncLoading) {
      ref.read(offlineAccessProvider.notifier).reloadSnapshot();
    }
    if (next is! AsyncData) return;
    final nextId = next.asData?.value?.id;
    // A failed/expired online profile restore is not an explicit SDK sign-out.
    if (nextId == null && ref.read(offlineAccessProvider).session != null) {
      return;
    }
    accept(nextId);
  });
  ref.listen(offlineAccessProvider, (previous, next) {
    if (next.status == OfflineAccessStatus.signedOut) {
      cleanedForUser = null;
      accept(null);
    } else if ((next.status == OfflineAccessStatus.available ||
            next.status == OfflineAccessStatus.expired) &&
        next.session != null) {
      // Includes expired sessions: keep their records, but remember identity
      // so signing into another account still clears the original account.
      accept(next.session!.userId);
      if (next.status == OfflineAccessStatus.available &&
          cleanedForUser != next.session!.userId) {
        cleanedForUser = next.session!.userId;
        final cache = ref.read(conversationCacheProvider);
        if (cache case final ConversationCacheAccountCleanup cleanup) {
          unawaited(
            cleanup.clearOtherUsers(cleanedForUser!).catchError((Object _) {}),
          );
        }
      }
    }
  });
});
