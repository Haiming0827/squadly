import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../../core/diagnostics/sentry_diagnostic_sink.dart';
import 'current_user_provider.dart';

abstract interface class DiagnosticConsentStore {
  Future<bool> read();
  Future<void> write(bool consent);
}

final class PreferencesDiagnosticConsentStore
    implements DiagnosticConsentStore {
  PreferencesDiagnosticConsentStore(String userId)
    : _key =
          'squadly.diagnostics.consent.v2.${base64Url.encode(utf8.encode(userId))}';
  final _preferences = SharedPreferencesAsync();
  final String _key;
  @override
  Future<bool> read() async => await _preferences.getBool(_key) ?? false;
  @override
  Future<void> write(bool consent) => _preferences.setBool(_key, consent);
}

final class DiagnosticSettings {
  const DiagnosticSettings({
    required this.available,
    this.enabled = false,
    this.saving = false,
    this.error,
  });
  final bool available;
  final bool enabled;
  final bool saving;
  final String? error;
}

final diagnosticsProvider =
    StateNotifierProvider<DiagnosticSettingsController, DiagnosticSettings>(
      (ref) => DiagnosticSettingsController(),
    );

/// Consent is revoked on confirmed sign-out or account change. Async loading
/// of the same account does not count as a change of user.
final diagnosticsAccountGuardProvider = Provider<void>((ref) {
  var confirmedId = ref.read(currentUserProvider).asData?.value?.id;
  Future.microtask(() {
    if (ref.mounted) {
      ref
          .read(diagnosticsProvider.notifier)
          .bindAccount(confirmedId, restoreConsent: true);
    }
  });
  ref.listen(currentUserProvider, (previous, next) {
    if (next is! AsyncData) return;
    final nextId = next.asData?.value?.id;
    if (confirmedId != nextId) {
      ref
          .read(diagnosticsProvider.notifier)
          .bindAccount(nextId, restoreConsent: confirmedId == null);
    }
    confirmedId = nextId;
  });
});

final class DiagnosticSettingsController
    extends StateNotifier<DiagnosticSettings> {
  DiagnosticSettingsController({
    this._store,
    this._reporter,
    this._closeSink,
    this._accountStoreFactory,
    bool available = false,
  }) : super(DiagnosticSettings(available: available));
  DiagnosticConsentStore? _store;
  final DiagnosticConsentStore Function(String)? _accountStoreFactory;
  String? _accountId;
  bool _accountBound = false;
  final DiagnosticReporter? _reporter;
  final void Function()? _closeSink;
  int _generation = 0;
  Future<void> _writes = Future.value();

  static DiagnosticSettingsController configured() {
    const dsn = String.fromEnvironment('SENTRY_DSN');
    if (dsn.isEmpty) return DiagnosticSettingsController();
    try {
      final sink = SentryDiagnosticSink(dsn);
      final reporter = DiagnosticReporter(
        sanitizer: DiagnosticSanitizer(
          version: '0.1.0+1',
          environment:
              const String.fromEnvironment(
                    'DIAGNOSTIC_ENVIRONMENT',
                    defaultValue: 'staging',
                  ) ==
                  'production'
              ? DiagnosticEnvironment.production
              : DiagnosticEnvironment.staging,
          allowedSources: const {
            'package:squadly/main.dart',
            'package:squadly/app/app.dart',
            'package:squadly/app/router.dart',
            'package:squadly/features/conversation/presentation/conversation_controller.dart',
            'package:squadly/features/conversation/presentation/conversation_screen.dart',
            'package:squadly/core/network/cloudbase_postgres_client.dart',
          },
        ),
        sink: sink,
        enabled: true,
        sampleRate: 1,
      );
      return DiagnosticSettingsController(
        accountStoreFactory: PreferencesDiagnosticConsentStore.new,
        reporter: reporter,
        closeSink: sink.close,
        available: true,
      );
    } catch (_) {
      return DiagnosticSettingsController();
    }
  }

  Future<void> restore() async {
    final generation = _generation;
    if (!state.available || _store == null) return;
    try {
      final consent = await _store!.read();
      if (!mounted || generation != _generation) return;
      _reporter?.setConsent(consent);
      state = DiagnosticSettings(available: true, enabled: consent);
    } catch (_) {
      /* Default remains disabled when local storage fails. */
    }
  }

  /// Production hooks stay disabled until the authenticated account and its
  /// own saved choice are known. Previous account writes keep their old store.
  void bindAccount(String? userId, {bool restoreConsent = false}) {
    if (_accountBound && _accountId == userId) return;
    if (_accountId != null) unawaited(setConsent(false));
    _accountBound = true;
    _accountId = userId;
    _generation++;
    _reporter?.setConsent(false);
    if (_accountStoreFactory != null) {
      _store = userId == null ? null : _accountStoreFactory(userId);
    }
    state = DiagnosticSettings(available: state.available);
    if (userId != null && restoreConsent) unawaited(restore());
  }

  Future<void> setConsent(bool consent) async {
    final generation = ++_generation;
    _reporter?.setConsent(false);
    final store = _store;
    if (!state.available || store == null) return;
    state = const DiagnosticSettings(available: true, saving: true);
    try {
      final write = _writes.then((_) => store.write(consent));
      _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
      await write;
      if (!mounted || generation != _generation) return;
      _reporter?.setConsent(consent);
      state = DiagnosticSettings(available: true, enabled: consent);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      state = const DiagnosticSettings(available: true, error: '设置保存失败，请重试');
    }
  }

  Future<DiagnosticCaptureResult> capture(Object error, StackTrace stack) =>
      state.enabled && _reporter != null
      ? _reporter.capture(error, stack)
      : Future.value(DiagnosticCaptureResult.disabled);

  @override
  void dispose() {
    _generation++;
    _reporter?.setConsent(false);
    _closeSink?.call();
    super.dispose();
  }
}
