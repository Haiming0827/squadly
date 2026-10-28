import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../features/auth/domain/offline_session.dart';

/// Explicitly wired by main. Widget fixtures/default demo never initialize an
/// SDK or read private native storage merely by displaying the login screen.
final offlineSessionSourceProvider = Provider<OfflineSessionSource?>(
  (ref) => null,
);

final offlineAccessProvider =
    StateNotifierProvider<OfflineAccessController, OfflineAccessState>(
      (ref) => OfflineAccessController(
        source: ref.watch(offlineSessionSourceProvider),
      ),
    );

enum OfflineAccessStatus {
  disabled,
  checking,
  available,
  expired,
  signedOut,
  unavailable,
}

final class OfflineAccessState {
  const OfflineAccessState(this.status, {this.session});
  final OfflineAccessStatus status;
  final OfflineSession? session;
  bool canReadAt(DateTime now) =>
      status == OfflineAccessStatus.available &&
      session?.isValidAt(now) == true;
}

final class OfflineAccessController extends StateNotifier<OfflineAccessState> {
  OfflineAccessController({
    OfflineSessionSource? source,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _source = source,
       super(
         OfflineAccessState(
           source == null
               ? OfflineAccessStatus.disabled
               : OfflineAccessStatus.checking,
         ),
       ) {
    _listen();
  }

  void _listen() {
    final generation = _generation;
    try {
      _subscription = _source?.watch().listen(
        (session) {
          if (mounted && generation == _generation) _accept(session);
        },
        onError: (Object _, StackTrace _) {
          if (!mounted || generation != _generation) return;
          _expiry?.cancel();
          state = const OfflineAccessState(OfflineAccessStatus.unavailable);
        },
      );
    } catch (_) {
      state = const OfflineAccessState(OfflineAccessStatus.unavailable);
    }
  }

  final DateTime Function() _clock;
  final OfflineSessionSource? _source;
  int _generation = 0;
  StreamSubscription<OfflineSession?>? _subscription;
  Timer? _expiry;

  void pauseForAuthentication() {
    if (_source == null || !mounted) return;
    _generation++;
    unawaited(_subscription?.cancel() ?? Future.value());
    _subscription = null;
    _expiry?.cancel();
    state = OfflineAccessState(
      OfflineAccessStatus.checking,
      session: state.session,
    );
  }

  /// Re-observe local SDK state after an authentication attempt, including a
  /// failed attempt that may have partially replaced its stored session.
  void reloadSnapshot() {
    if (_source == null || !mounted) return;
    pauseForAuthentication();
    _listen();
  }

  void _accept(OfflineSession? session) {
    if (!mounted) return;
    _expiry?.cancel();
    if (session == null) {
      state = const OfflineAccessState(OfflineAccessStatus.signedOut);
      return;
    }
    if (!session.isValidAt(_clock())) {
      state = OfflineAccessState(OfflineAccessStatus.expired, session: session);
      return;
    }
    state = OfflineAccessState(OfflineAccessStatus.available, session: session);
    final delay = session.expiresAt.difference(_clock());
    _expiry = Timer(delay.isNegative ? Duration.zero : delay, checkExpiry);
  }

  void checkExpiry() {
    if (!mounted) return;
    final session = state.session;
    if (state.status == OfflineAccessStatus.available && session != null) {
      _accept(session);
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    unawaited(_subscription?.cancel() ?? Future.value());
    super.dispose();
  }
}
