import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/providers/conversation_cache_lifecycle_provider.dart';
import 'package:squadly/app/providers/conversation_cache_provider.dart';
import 'package:squadly/app/providers/current_user_provider.dart';
import 'package:squadly/app/providers/diagnostics_provider.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/conversation/domain/conversation_cache.dart';

void main() {
  test('only confirmed sign-out/account change clears old sent cache and revokes consent', () async {
    final identity = StateProvider<AsyncValue<User?>>(
      (ref) => AsyncData(_user('a')),
    );
    final cache = _Cache();
    final controller = DiagnosticSettingsController(
      store: _Store(),
      available: true,
    );
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(identity)),
        conversationCacheProvider.overrideWithValue(cache),
        diagnosticsProvider.overrideWith((ref) => controller),
      ],
    );
    addTearDown(container.dispose);
    container.listen(conversationCacheLifecycleProvider, (_, _) {});
    container.listen(diagnosticsAccountGuardProvider, (_, _) {});
    await container.pump();
    await controller.setConsent(true);
    container.read(identity.notifier).state = const AsyncLoading<User?>();
    await container.pump();
    expect(cache.cleared, isEmpty);
    expect(controller.state.enabled, isTrue);
    container.read(identity.notifier).state = AsyncData(_user('a'));
    await container.pump();
    expect(cache.cleared, isEmpty);
    container.read(identity.notifier).state = AsyncData(_user('b'));
    await container.pump();
    expect(cache.cleared, ['a']);
    expect(cache.resumed, ['b']);
    expect(controller.state.enabled, isFalse);
    await controller.setConsent(true);
    container.read(identity.notifier).state = const AsyncData(null);
    await container.pump();
    expect(cache.cleared, ['a', 'b']);
    expect(controller.state.enabled, isFalse);
  });
}

User _user(String id) =>
    User(id: id, nickname: id, createdAt: DateTime.utc(2026));

class _Cache implements ConversationCache {
  final cleared = <String>[];
  final resumed = <String>[];
  @override
  Future<void> clearUser(String userId, {bool suspend = false}) async {
    expect(suspend, isTrue);
    cleared.add(userId);
  }

  @override
  void resumeUser(String userId) {
    resumed.add(userId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store implements DiagnosticConsentStore {
  bool value = false;
  @override
  Future<bool> read() async => value;
  @override
  Future<void> write(bool consent) async {
    value = consent;
  }
}
