import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/app/providers/conversation_cache_provider.dart';
import 'package:squadly/app/providers/offline_access_provider.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/auth/domain/offline_session.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/conversation/domain/conversation_cache.dart';

void main() {
  test(
    'SDK identity clears records even before online profile has restored',
    () async {
      final cache = _Cache();
      final container = ProviderContainer(
        overrides: [
          conversationCacheProvider.overrideWithValue(cache),
          offlineSessionSourceProvider.overrideWithValue(_StoredSession()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(offlineAccessProvider, (_, _) {});
      await container.pump();
      expect(container.read(authNotifierProvider).value, isNull);
      expect(
        await container.read(authNotifierProvider.notifier).signOut(),
        isNull,
      );
      expect(cache.cleared, ['sdk-account']);
    },
  );

  test('requiring online login retains records and supersedes the old profile state', () {
    final cache = _Cache();
    final container = ProviderContainer(
      overrides: [conversationCacheProvider.overrideWithValue(cache)],
    );
    addTearDown(container.dispose);
    container
        .read(demoAppStoreProvider.notifier)
        .signInWithEmail(email: 'local@example.test', password: 'password1');
    container.read(authNotifierProvider.notifier).requireOnlineLogin();
    expect(container.read(authNotifierProvider).hasError, isTrue);
    expect(cache.cleared, isEmpty);
  });

  test('sign-out awaits sent-record cleanup before closing account', () async {
    final cache = _Cache()..gate = Completer<void>();
    final container = ProviderContainer(
      overrides: [conversationCacheProvider.overrideWithValue(cache)],
    );
    addTearDown(container.dispose);
    final user = container
        .read(demoAppStoreProvider.notifier)
        .signInWithEmail(email: 'local@example.test', password: 'password1');
    final pending = container.read(authNotifierProvider.notifier).signOut();
    expect(cache.cleared, [user.id]);
    expect(container.read(authNotifierProvider).asData?.value?.id, user.id);
    cache.gate!.complete();
    expect(await pending, isNull);
    expect(container.read(authNotifierProvider).asData?.value, isNull);
  });
  test(
    'failed cleanup preserves account and returns a retryable failure',
    () async {
      final cache = _Cache()..fail = true;
      final container = ProviderContainer(
        overrides: [conversationCacheProvider.overrideWithValue(cache)],
      );
      addTearDown(container.dispose);
      final user = container
          .read(demoAppStoreProvider.notifier)
          .signInWithEmail(email: 'local@example.test', password: 'password1');
      expect(
        await container.read(authNotifierProvider.notifier).signOut(),
        isA<UnknownFailure>(),
      );
      expect(container.read(authNotifierProvider).asData?.value?.id, user.id);
      expect(cache.resumed, [user.id]);
    },
  );
}

class _Cache implements ConversationCache {
  Completer<void>? gate;
  bool fail = false;
  final cleared = <String>[];
  final resumed = <String>[];
  @override
  Future<void> clearUser(String userId, {bool suspend = false}) async {
    expect(suspend, isTrue);
    cleared.add(userId);
    if (fail) throw StateError('unavailable');
    await gate?.future;
  }

  @override
  void resumeUser(String userId) => resumed.add(userId);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StoredSession implements OfflineSessionSource {
  @override
  Stream<OfflineSession?> watch() => Stream.value(
    OfflineSession(
      userId: 'sdk-account',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
  );
}
