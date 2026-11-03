import 'dart:async';

import 'package:cloudbase_flutter/cloudbase_flutter.dart';

/// Per-SDK-instance ordering. A timed-out caller cannot release an SDK request
/// that still writes session state; mutations wait for its real completion.
final class CloudBaseAuthGate {
  CloudBaseAuthGate._(this._auth);
  static final _instances = Expando<CloudBaseAuthGate>();
  static CloudBaseAuthGate forAuth(CloudBaseAuth auth) =>
      _instances[auth] ??= CloudBaseAuthGate._(auth);
  final CloudBaseAuth _auth;
  Future<void> _tail = Future.value();
  Future<SignInRes>? _session;
  int _epoch = 0;

  Future<T> _schedule<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  /// SDK reads may refresh internally, so they share the write ordering too.
  Future<T> read<T>(Future<T> Function() action) => _schedule(action);

  /// Register intent immediately, before waiting for earlier SDK work.
  Future<T> mutate<T>(Future<T> Function() action) {
    _epoch++;
    _session = null;
    return _schedule(action);
  }

  Future<SignInRes> session({bool Function()? isCurrent}) {
    final current = _session;
    if (isCurrent == null && current != null) return current;
    final epoch = _epoch;
    bool allowed() => epoch == _epoch && (isCurrent?.call() ?? true);
    SignInRes stale() => SignInRes(
      error: AuthError(
        code: 'session_changed',
        message: 'Session request superseded',
      ),
    );
    final next = _schedule(() async {
      if (!allowed()) return stale();
      final response = await _auth.getSession();
      return allowed() ? response : stale();
    });
    if (isCurrent != null) return next;
    late final Future<SignInRes> tracked;
    tracked = next.whenComplete(() {
      if (identical(_session, tracked)) _session = null;
    });
    _session = tracked;
    return tracked;
  }
}
