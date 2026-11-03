import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/providers/offline_access_provider.dart';
import 'package:squadly/features/auth/domain/offline_session.dart';

void main() {
  test('authentication pauses viewing and then re-observes the actual SDK snapshot', () async {
    final now = DateTime.now();
    final source = _SnapshotSource(
      OfflineSession(userId: 'a', expiresAt: now.add(const Duration(hours: 1))),
    );
    final controller = OfflineAccessController(source: source);
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.session!.userId, 'a');
    controller.pauseForAuthentication();
    expect(controller.state.initialRestoration, isFalse);
    expect(controller.state.canReadAt(now), isFalse);
    source.current = OfflineSession(
      userId: 'b',
      expiresAt: now.add(const Duration(hours: 1)),
    );
    controller.reloadSnapshot();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.session!.userId, 'b');
    expect(controller.state.canReadAt(now), isTrue);
  });
  test(
    'initial restoration is distinct from an explicit authentication pause',
    () {
      final source = _Source();
      final controller = OfflineAccessController(source: source);
      addTearDown(controller.dispose);
      addTearDown(source.events.close);
      expect(controller.state.initialRestoration, isTrue);
      controller.pauseForAuthentication();
      expect(controller.state.initialRestoration, isFalse);
    },
  );
  test('no source is disabled and cannot unlock cache', () {
    final controller = OfflineAccessController();
    addTearDown(controller.dispose);
    expect(controller.state.status, OfflineAccessStatus.disabled);
    expect(controller.state.canReadAt(DateTime.now()), isFalse);
  });
  testWidgets(
    'local expiry timer locks viewing without dropping account identity',
    (tester) async {
      final source = _Source();
      var now = DateTime.utc(2026);
      final controller = OfflineAccessController(
        source: source,
        clock: () => now,
      );
      addTearDown(controller.dispose);
      addTearDown(source.events.close);
      expect(controller.state.status, OfflineAccessStatus.checking);
      source.events.add(
        OfflineSession(
          userId: 'a',
          expiresAt: now.add(const Duration(seconds: 2)),
        ),
      );
      expect(controller.state.canReadAt(now), isTrue);
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(controller.state.status, OfflineAccessStatus.expired);
      expect(controller.state.session!.userId, 'a');
      expect(controller.state.canReadAt(now), isFalse);
      source.events.add(
        OfflineSession(
          userId: 'a',
          expiresAt: now.add(const Duration(minutes: 1)),
        ),
      );
      expect(controller.state.canReadAt(now), isTrue);
      source.events.add(null);
    },
  );
  test(
    'resume check and account changes fail closed on unavailable SDK data',
    () async {
      final source = _Source();
      var now = DateTime.utc(2026);
      final controller = OfflineAccessController(
        source: source,
        clock: () => now,
      );
      addTearDown(controller.dispose);
      addTearDown(source.events.close);
      source.events.add(
        OfflineSession(
          userId: 'a',
          expiresAt: now.add(const Duration(seconds: 1)),
        ),
      );
      now = now.add(const Duration(seconds: 2));
      controller.checkExpiry();
      expect(controller.state.status, OfflineAccessStatus.expired);
      source.events.add(
        OfflineSession(
          userId: 'b',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );
      expect(controller.state.session!.userId, 'b');
      source.events.addError(StateError('not logged or uploaded'));
      expect(controller.state.status, OfflineAccessStatus.unavailable);
      expect(controller.state.canReadAt(now), isFalse);
      source.events.add(null);
      expect(controller.state.status, OfflineAccessStatus.signedOut);
    },
  );
}

class _Source implements OfflineSessionSource {
  final events = StreamController<OfflineSession?>.broadcast(sync: true);
  @override
  Stream<OfflineSession?> watch() => events.stream;
}

class _SnapshotSource implements OfflineSessionSource {
  _SnapshotSource(this.current);
  OfflineSession? current;
  @override
  Stream<OfflineSession?> watch() => Stream.value(current);
}
