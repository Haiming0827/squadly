import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/photo_widget/data/photo_background_credentials.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget.dart';

const _binding = '00000000-0000-4000-8000-000000000001';
const _generation = '00000000-0000-4000-8000-000000000002';
const _ticket = '00000000-0000-4000-8000-000000000003';
final _now = DateTime.utc(2026, 10, 28);
PhotoWidgetSnapshot _state({
  bool preview = true,
  String generation = _generation,
}) => PhotoWidgetSnapshot(
  display: preview ? PhotoWidgetDisplay.photo : PhotoWidgetDisplay.hidden,
  scheme: 'squadly',
  lease: PhotoWidgetLease(
    scope: 'a' * 64,
    generation: generation,
    expiresAt: _now.add(const Duration(hours: 1)),
  ),
  binding: PhotoWidgetBinding(
    id: _binding,
    scope: 'a' * 64,
    squadId: _binding,
    squadName: '小队',
    previewEnabled: preview,
  ),
);
PhotoBackgroundCredentialMaterial _material() =>
    PhotoBackgroundCredentialMaterial(
      environmentId: 'fixture-env',
      region: 'ap-shanghai',
      userId: 'fixture-user',
      gateway: Uri.parse(
        'https://fixture-env-123.ap-shanghai.app.tcloudbase.com/photos',
      ),
      accessToken: 'synthetic-test-token',
      expiresAt: _now.add(const Duration(minutes: 30)),
    );

class _Bridge implements PhotoBackgroundCredentialBridge {
  int prepares = 0, commits = 0, clears = 0;
  String? pending;
  final cancelled = <String>[];
  bool failCommit = false;
  Completer<String>? prepareGate;
  Completer<void>? clearGate;
  @override
  Future<String> prepare(PhotoWidgetSnapshot expected) async {
    prepares++;
    pending = 'ticket-$prepares';
    return prepareGate?.future ?? Future.value(pending!);
  }

  @override
  Future<void> commit(
    String ticket,
    PhotoBackgroundCredentialMaterial material,
  ) async {
    if (failCommit || pending != ticket) throw StateError('stale');
    pending = null;
    commits++;
  }

  @override
  Future<void> cancel(String ticket) async {
    cancelled.add(ticket);
    if (pending == ticket) pending = null;
  }

  @override
  Future<void> clear() async {
    clears++;
    if (clearGate != null) await clearGate!.future;
    pending = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Bridge bridge;
  late PhotoBackgroundCredentialController controller;
  var reads = 0;
  setUp(() {
    bridge = _Bridge();
    reads = 0;
    controller = PhotoBackgroundCredentialController(
      bridge: bridge,
      read: () async {
        reads++;
        return _material();
      },
      clock: () => _now,
    );
  });
  test(
    'hidden, expired and unavailable snapshots never read SDK material',
    () async {
      for (final state in [
        _state(preview: false),
        _state().copyWith(lease: _state().lease!.copyWith(expiresAt: _now)),
        _state().copyWith(display: PhotoWidgetDisplay.unavailable),
      ]) {
        await controller.reset();
        await controller.accept(state);
      }
      expect(reads, 0);
      expect(bridge.prepares, 0);
      expect(bridge.commits, 0);
    },
  );
  test(
    'repeated display updates coalesce one credential per binding lease',
    () async {
      await controller.accept(_state());
      await controller.accept(_state().copyWith(messageId: 'new-photo'));
      expect(reads, 1);
      expect(bridge.prepares, 1);
      expect(bridge.commits, 1);
    },
  );
  test('a slow SDK read cannot commit after preview is disabled', () async {
    final gate = Completer<PhotoBackgroundCredentialMaterial?>();
    controller = PhotoBackgroundCredentialController(
      bridge: bridge,
      read: () => gate.future,
      clock: () => _now,
    );
    final pending = controller.accept(_state());
    await Future<void>.delayed(Duration.zero);
    await controller.accept(_state(preview: false));
    gate.complete(_material());
    await pending;
    expect(bridge.commits, 0);
    expect(bridge.cancelled, ['ticket-1']);
  });
  test('new prepare invalidates an older SDK result without cancelling the new ticket', () async {
    final first = Completer<PhotoBackgroundCredentialMaterial?>();
    var count = 0;
    controller = PhotoBackgroundCredentialController(
      bridge: bridge,
      read: () => ++count == 1 ? first.future : Future.value(_material()),
      clock: () => _now,
    );
    final old = controller.accept(_state());
    await Future<void>.delayed(Duration.zero);
    await controller.accept(_state(generation: _ticket));
    first.complete(_material());
    await old;
    expect(bridge.commits, 1);
    expect(bridge.cancelled, ['ticket-1']);
  });
  test('reset and disposal fence in-flight SDK reads', () async {
    for (final dispose in [false, true]) {
      final gate = Completer<PhotoBackgroundCredentialMaterial?>();
      controller = PhotoBackgroundCredentialController(
        bridge: bridge,
        read: () => gate.future,
        clock: () => _now,
      );
      final pending = controller.accept(_state());
      await Future<void>.delayed(Duration.zero);
      await (dispose ? controller.dispose() : controller.reset());
      gate.complete(_material());
      await pending;
    }
    expect(bridge.commits, 0);
    expect(bridge.clears, 2);
  });
  test('null SDK material cancels its ticket and can be retried', () async {
    var ready = false;
    controller = PhotoBackgroundCredentialController(
      bridge: bridge,
      read: () async => ready ? _material() : null,
      clock: () => _now,
    );
    await controller.accept(_state());
    ready = true;
    await controller.accept(_state());
    expect(bridge.cancelled, ['ticket-1']);
    expect(bridge.commits, 1);
  });
  test(
    'native commit failure is retryable and never reports success',
    () async {
      bridge.failCommit = true;
      await controller.accept(_state());
      expect(bridge.commits, 0);
      bridge.failCommit = false;
      await controller.accept(_state());
      expect(bridge.commits, 1);
      expect(bridge.cancelled, ['ticket-1']);
    },
  );
  test(
    'duplicate accept while SDK is pending shares the same future',
    () async {
      final gate = Completer<PhotoBackgroundCredentialMaterial?>();
      controller = PhotoBackgroundCredentialController(
        bridge: bridge,
        read: () {
          reads++;
          return gate.future;
        },
        clock: () => _now,
      );
      final one = controller.accept(_state()),
          two = controller.accept(_state());
      expect(identical(one, two), isTrue);
      gate.complete(_material());
      await one;
      expect(reads, 1);
      expect(bridge.commits, 1);
    },
  );
  test(
    'new preparation waits until an older reset has finished clearing',
    () async {
      final gate = Completer<void>();
      bridge.clearGate = gate;
      final clearing = controller.reset();
      final preparing = controller.accept(_state());
      await Future<void>.delayed(Duration.zero);
      expect(
        bridge.prepares,
        0,
        reason: 'A late clear must not erase a new credential',
      );
      gate.complete();
      await clearing;
      await preparing;
      expect(bridge.commits, 1);
    },
  );
  test('material description is redacted', () {
    expect(
      _material().toString(),
      'PhotoBackgroundCredentialMaterial(<redacted>)',
    );
  });
  test(
    'native bridge uses a separate channel with exact short-term fields',
    () async {
      const channel = MethodChannel('squadly/photo-background-fixture');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'prepare' ? _ticket : true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const native = NativePhotoBackgroundCredentialBridge(channel);
      final ticket = await native.prepare(_state());
      await native.commit(ticket, _material());
      await native.cancel(ticket);
      await native.clear();
      expect(calls.map((c) => c.method), [
        'prepare',
        'commit',
        'cancel',
        'clear',
      ]);
      expect((calls[1].arguments as Map).keys.toSet(), {
        'ticket',
        'environmentId',
        'region',
        'userId',
        'gateway',
        'accessToken',
        'expiresAt',
      });
    },
  );
}
