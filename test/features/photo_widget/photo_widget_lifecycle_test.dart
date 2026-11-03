import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/app/providers/photo_widget_providers.dart';
import 'package:squadly/features/conversation/domain/photo_head.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget_lifecycle.dart';

import 'photo_widget_service_test.dart' show Harness, messageId, image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(
      const PhotoWidgetSnapshot(
        display: PhotoWidgetDisplay.empty,
        scheme: 'squadly',
      ),
    );
    registerFallbackValue(const PhotoHead(revision: '0'));
    registerFallbackValue(DateTime.utc(2026));
    registerFallbackValue(image());
  });
  test(
    'recovery defers positive synchronization but logout clears immediately',
    () async {
      final h = Harness();
      await h.init();
      var clears = 0;
      final lifecycle = PhotoWidgetLifecycle(
        store: h.store,
        service: h.service,
        clearCredentials: () async => clears++,
      );
      lifecycle.beginRecovery();
      await lifecycle.accept((
        mode: PhotoWidgetAccessMode.ready,
        context: h.owner,
      ), foreground: false);
      verifyNever(
        () => h.store.synchronize(
          scope: any(named: 'scope'),
          expiresAt: any(named: 'expiresAt'),
        ),
      );
      await lifecycle.accept((
        mode: PhotoWidgetAccessMode.blocked,
        context: null,
      ), foreground: false);
      expect(clears, 1);
      await lifecycle.endRecovery();
      verify(() => h.store.synchronize(scope: null, expiresAt: null)).called(1);
      expect(h.latestCalls, 0);
    },
  );
  test(
    'successful recovery applies the latest positive identity after release',
    () async {
      final h = Harness();
      await h.init();
      final lifecycle = PhotoWidgetLifecycle(
        store: h.store,
        service: h.service,
        clearCredentials: () async => fail('No logout'),
      );
      lifecycle.beginRecovery();
      await lifecycle.accept((
        mode: PhotoWidgetAccessMode.ready,
        context: h.owner,
      ), foreground: false);
      await lifecycle.endRecovery();
      verify(
        () => h.store.synchronize(
          scope: any(named: 'scope'),
          expiresAt: h.owner!.expiresAt,
        ),
      ).called(1);
      expect(h.loadCalls, 0);
    },
  );
  test(
    'expired SDK reference purges credentials without authorizing a refresh',
    () async {
      final h = Harness();
      await h.init();
      when(
        () => h.store.retainExpired(
          scope: any(named: 'scope'),
          expiresAt: any(named: 'expiresAt'),
        ),
      ).thenAnswer((_) async => h.state);
      var expirations = 0;
      final lifecycle = PhotoWidgetLifecycle(
        store: h.store,
        service: h.service,
        clearCredentials: () async => fail('No logout'),
        expireCredentials: () async => expirations++,
      );
      await lifecycle.accept((
        mode: PhotoWidgetAccessMode.expired,
        context: h.owner!.copyWith(expiresAt: DateTime.utc(2020)),
      ), foreground: false);
      expect(expirations, 1);
      expect(h.loadCalls, 0);
      verifyNever(
        () => h.store.synchronize(
          scope: any(named: 'scope'),
          expiresAt: any(named: 'expiresAt'),
        ),
      );
    },
  );
  test(
    'foreign or missing expired reference is cleared rather than reconstructed',
    () async {
      final h = Harness();
      await h.init();
      when(
        () => h.store.retainExpired(
          scope: any(named: 'scope'),
          expiresAt: any(named: 'expiresAt'),
        ),
      ).thenThrow(StateError('scope mismatch'));
      var clears = 0;
      final lifecycle = PhotoWidgetLifecycle(
        store: h.store,
        service: h.service,
        clearCredentials: () async => clears++,
      );
      await lifecycle.accept((
        mode: PhotoWidgetAccessMode.expired,
        context: h.owner!.copyWith(expiresAt: DateTime.utc(2020)),
      ), foreground: false);
      expect(clears, 1);
      verify(() => h.store.synchronize(scope: null, expiresAt: null)).called(1);
      expect(h.loadCalls, 0);
    },
  );
  test(
    'a ready different account revokes old scope without waiting for recovery',
    () async {
      final h = Harness();
      await h.init();
      final scope = await photoWidgetScope(h.owner!);
      final lifecycle = PhotoWidgetLifecycle(
        store: h.store,
        service: h.service,
        clearCredentials: () async {},
      );
      lifecycle.beginRecovery(scope: scope);
      final other = h.owner!.copyWith(userId: 'different-account');
      await lifecycle
          .accept((
            mode: PhotoWidgetAccessMode.ready,
            context: other,
          ), foreground: false)
          .timeout(const Duration(seconds: 1));
      verify(
        () => h.store.synchronize(
          scope: any(named: 'scope'),
          expiresAt: other.expiresAt,
        ),
      ).called(1);
      expect(h.loadCalls, 0);
    },
  );
  test(
    'late expired-reference failure cannot clear a newer recovery',
    () async {
      final h = Harness();
      await h.init();
      final waiting = Completer<PhotoWidgetSnapshot>();
      when(
        () => h.store.retainExpired(
          scope: any(named: 'scope'),
          expiresAt: any(named: 'expiresAt'),
        ),
      ).thenAnswer((_) => waiting.future);
      var clears = 0;
      final lifecycle = PhotoWidgetLifecycle(
        store: h.store,
        service: h.service,
        clearCredentials: () async => clears++,
      );
      final earlier = lifecycle.accept((
        mode: PhotoWidgetAccessMode.expired,
        context: h.owner!.copyWith(expiresAt: DateTime.utc(2020)),
      ), foreground: false);
      await Future<void>.delayed(Duration.zero);
      lifecycle.beginRecovery(scope: await photoWidgetScope(h.owner!));
      waiting.completeError(StateError('old expired context'));
      await earlier;
      expect(clears, 0);
      await lifecycle.endRecovery();
    },
  );
  test(
    'logout clears credentials even when the extension is not installed',
    () async {
      final h = Harness();
      await h.init();
      when(() => h.store.isAvailable()).thenAnswer((_) async => false);
      var clears = 0;
      final lifecycle = PhotoWidgetLifecycle(
        store: h.store,
        service: h.service,
        clearCredentials: () async => clears++,
      );
      await lifecycle.accept((
        mode: PhotoWidgetAccessMode.blocked,
        context: null,
      ), foreground: true);
      expect(clears, 1);
      verify(() => h.store.synchronize(scope: null, expiresAt: null)).called(1);
    },
  );
  test(
    'an unavailable extension does not issue a foreground refresh',
    () async {
      final h = Harness();
      await h.init();
      when(() => h.store.isAvailable()).thenAnswer((_) async => false);
      final lifecycle = PhotoWidgetLifecycle(
        store: h.store,
        service: h.service,
        clearCredentials: () async {},
      );
      await lifecycle.accept((
        mode: PhotoWidgetAccessMode.ready,
        context: h.owner,
      ), foreground: true);
      expect(h.latestCalls, 0);
      expect(h.loadCalls, 0);
    },
  );
  test('restoration preserves same-account cache without starting a foreground fetch', () async {
    final h = Harness();
    await h.init();
    h.state = h.state.copyWith(
      display: PhotoWidgetDisplay.photo,
      messageId: messageId,
    );
    when(() => h.store.isAvailable()).thenAnswer((_) async => true);
    var clears = 0;
    final lifecycle = PhotoWidgetLifecycle(
      store: h.store,
      service: h.service,
      clearCredentials: () async => clears++,
    );
    await lifecycle.accept((
      mode: PhotoWidgetAccessMode.restoring,
      context: null,
    ), foreground: true);
    await lifecycle.accept((
      mode: PhotoWidgetAccessMode.restoring,
      context: h.owner,
    ), foreground: true);
    expect(h.state.messageId, messageId);
    expect(h.latestCalls, 0);
    expect(h.loadCalls, 0);
    expect(clears, 0);
    verifyNever(() => h.store.synchronize(scope: null, expiresAt: null));
  });
  test(
    'ready background bootstrap does not replace credentials or fetch twice',
    () async {
      final h = Harness();
      await h.init();
      when(() => h.store.isAvailable()).thenAnswer((_) async => true);
      final lifecycle = PhotoWidgetLifecycle(
        store: h.store,
        service: h.service,
        clearCredentials: () async => fail('No logout'),
      );
      final authority = (mode: PhotoWidgetAccessMode.ready, context: h.owner);
      await lifecycle.accept(authority, foreground: false);
      expect(h.latestCalls, 0);
      expect(h.loadCalls, 0);
      await lifecycle.accept(authority, foreground: true, force: true);
      expect(h.loadCalls, 1);
    },
  );
  test('blocked authority clears immediately while a previous network refresh is pending', () async {
    final h = Harness();
    await h.init();
    when(() => h.store.isAvailable()).thenAnswer((_) async => true);
    final head = Completer<Either<Never, PhotoHead>>();
    h.latest = () => head.future;
    var clears = 0;
    final lifecycle = PhotoWidgetLifecycle(
      store: h.store,
      service: h.service,
      clearCredentials: () async => clears++,
    );
    final fetching = lifecycle.accept((
      mode: PhotoWidgetAccessMode.ready,
      context: h.owner,
    ), foreground: true);
    while (h.latestCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    await lifecycle
        .accept((
          mode: PhotoWidgetAccessMode.blocked,
          context: null,
        ), foreground: true)
        .timeout(const Duration(seconds: 1));
    expect(clears, 1);
    verify(() => h.store.synchronize(scope: null, expiresAt: null)).called(1);
    head.complete(right(const PhotoHead(revision: '2')));
    await fetching;
    verifyNever(
      () => h.store.applyHead(
        expected: any(named: 'expected'),
        head: any(named: 'head'),
        image: any(named: 'image'),
      ),
    );
  });
  test('a pending clear blocks local ready synchronization, but latest authority wins', () async {
    final h = Harness();
    await h.init();
    when(() => h.store.isAvailable()).thenAnswer((_) async => true);
    final clear = Completer<void>();
    final lifecycle = PhotoWidgetLifecycle(
      store: h.store,
      service: h.service,
      clearCredentials: () => clear.future,
    );
    final blocked = lifecycle.accept((
      mode: PhotoWidgetAccessMode.blocked,
      context: null,
    ), foreground: true);
    await Future<void>.delayed(Duration.zero);
    final restored = lifecycle.accept((
      mode: PhotoWidgetAccessMode.ready,
      context: h.owner,
    ), foreground: true);
    await Future<void>.delayed(Duration.zero);
    expect(h.latestCalls, 0);
    clear.complete();
    await blocked;
    await restored;
    expect(h.loadCalls, 1);
    verifyNever(() => h.store.synchronize(scope: null, expiresAt: null));
  });
  test(
    'cold ready startup keeps valid pixels until an authoritative head arrives',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final h = Harness();
      await h.init();
      h.state = h.state.copyWith(
        display: PhotoWidgetDisplay.photo,
        messageId: messageId,
      );
      when(() => h.store.isAvailable()).thenAnswer((_) async => true);
      when(
        () => h.store.synchronize(
          scope: any(named: 'scope'),
          expiresAt: any(named: 'expiresAt'),
        ),
      ).thenAnswer((call) async {
        if (call.namedArguments[#scope] == null) {
          h.state = h.state.copyWith(
            display: PhotoWidgetDisplay.signedOut,
            messageId: null,
          );
        }
        return h.state;
      });
      final head = Completer<Either<Never, PhotoHead>>();
      h.latest = () => head.future;
      final container = ProviderContainer(
        overrides: [
          photoWidgetContextProvider.overrideWithValue(h.owner),
          photoWidgetStoreProvider.overrideWithValue(h.store),
          photoWidgetAuthorityProvider.overrideWithValue((
            mode: PhotoWidgetAccessMode.ready,
            context: h.owner,
          )),
          photoWidgetServiceProvider.overrideWithValue(h.service),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        photoWidgetLifecycleProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        h.state.messageId,
        messageId,
        reason: 'Starting Dart must not erase a valid native cache',
      );
      head.complete(right(const PhotoHead(revision: '2')));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(h.state.messageId, isNull);
    },
  );
}
