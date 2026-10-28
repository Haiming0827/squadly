import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/providers/diagnostics_provider.dart';
import 'package:squadly/core/diagnostics/diagnostics.dart';

void main() {
  test(
    'configured transport cannot restore consent before identity is known',
    () async {
      final a = _Store()..value = true;
      final b = _Store();
      final controller = DiagnosticSettingsController(
        accountStoreFactory: (id) => id == 'a' ? a : b,
        available: true,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      await controller.setConsent(true);
      expect(controller.state.enabled, isFalse);
      controller.bindAccount('a', restoreConsent: true);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.enabled, isTrue);
      controller.bindAccount('b');
      await Future<void>.delayed(Duration.zero);
      expect(a.value, isFalse);
      expect(b.value, isFalse);
      expect(controller.state.enabled, isFalse);
    },
  );

  test(
    'queued old-account consent writes cannot change the new account store',
    () async {
      final gate = Completer<void>();
      final a = _Store()..writeGate = gate;
      final b = _Store();
      final controller = DiagnosticSettingsController(
        accountStoreFactory: (id) => id == 'a' ? a : b,
        available: true,
      );
      addTearDown(controller.dispose);
      controller.bindAccount('a');
      final oldWrite = controller.setConsent(true);
      controller.bindAccount('b');
      final newWrite = controller.setConsent(true);
      gate.complete();
      await Future.wait([oldWrite, newWrite]);
      expect(a.value, isFalse);
      expect(b.value, isTrue);
      expect(controller.state.enabled, isTrue);
    },
  );
  test('missing configuration stays off and cannot capture', () async {
    final controller = DiagnosticSettingsController();
    addTearDown(controller.dispose);
    await controller.restore();
    await controller.setConsent(true);
    expect(controller.state.available, isFalse);
    expect(controller.state.enabled, isFalse);
    expect(
      await controller.capture(StateError('private'), StackTrace.empty),
      DiagnosticCaptureResult.disabled,
    );
  });
  test('default off; consent persists before submission and revocation stops capture', () async {
    final store = _Store();
    final sink = _Sink();
    final reporter = DiagnosticReporter(
      sanitizer: DiagnosticSanitizer(
        version: '0.1.0',
        environment: DiagnosticEnvironment.staging,
        allowedSources: {},
      ),
      sink: sink,
      enabled: true,
      sampleRate: 1,
    );
    final controller = DiagnosticSettingsController(
      store: store,
      reporter: reporter,
      available: true,
    );
    addTearDown(controller.dispose);
    await controller.restore();
    expect(controller.state.enabled, isFalse);
    await controller.capture(StateError('private'), StackTrace.empty);
    expect(sink.count, 0);
    await controller.setConsent(true);
    expect(store.value, isTrue);
    await controller.capture(StateError('private'), StackTrace.empty);
    expect(sink.count, 1);
    await controller.setConsent(false);
    expect(store.value, isFalse);
    expect(
      await controller.capture(StateError('private'), StackTrace.empty),
      DiagnosticCaptureResult.disabled,
    );
  });
  test('failed consent persistence never enables reporting', () async {
    final controller = DiagnosticSettingsController(
      store: _Store()..fail = true,
      available: true,
    );
    addTearDown(controller.dispose);
    await controller.setConsent(true);
    expect(controller.state.enabled, isFalse);
    expect(controller.state.error, '设置保存失败，请重试');
  });
  test('late restore cannot override a user revocation', () async {
    final gate = Completer<bool>();
    final controller = DiagnosticSettingsController(
      store: _Store()..readGate = gate,
      available: true,
    );
    addTearDown(controller.dispose);
    final restore = controller.restore();
    await controller.setConsent(false);
    gate.complete(true);
    await restore;
    expect(controller.state.enabled, isFalse);
  });
}

class _Store implements DiagnosticConsentStore {
  bool value = false;
  bool fail = false;
  Completer<bool>? readGate;
  Completer<void>? writeGate;
  @override
  Future<bool> read() async =>
      readGate == null ? value : await readGate!.future;
  @override
  Future<void> write(bool consent) async {
    await writeGate?.future;
    if (fail) throw StateError('private storage info');
    value = consent;
  }
}

class _Sink implements DiagnosticSink {
  int count = 0;
  @override
  Future<void> submit(DiagnosticEvent event) async {
    count++;
  }
}
