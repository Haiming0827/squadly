import 'photo_widget.dart';
import 'photo_widget_service.dart';

enum PhotoWidgetAccessMode { restoring, ready, expired, blocked }

typedef PhotoWidgetAuthority = ({
  PhotoWidgetAccessMode mode,
  PhotoWidgetContext? context,
});

/// Local mutations are ordered; network refresh never blocks later revocation.
final class PhotoWidgetLifecycle {
  PhotoWidgetLifecycle({
    required this.store,
    required this.service,
    required this.clearCredentials,
    Future<void> Function()? expireCredentials,
  }) : expireCredentials = expireCredentials ?? clearCredentials;
  final PhotoWidgetStore store;
  final PhotoWidgetService service;
  final Future<void> Function() clearCredentials;
  final Future<void> Function() expireCredentials;
  bool _holding = false;
  String? _recoveryScope;
  ({PhotoWidgetAuthority authority, bool foreground})? _deferred;

  void beginRecovery({String? scope}) {
    _holding = true;
    _recoveryScope = scope;
    _revision++;
    _running = false;
    service.cancelPendingRefresh();
  }

  Future<void> endRecovery() {
    _holding = false;
    _recoveryScope = null;
    final deferred = _deferred;
    _deferred = null;
    if (deferred == null || !_active) return Future.value();
    return accept(
      deferred.authority,
      foreground: deferred.foreground,
      force: true,
    );
  }

  int _revision = 0;
  bool _active = true;
  PhotoWidgetAuthority? _last;
  bool? _foreground;
  Future<void> _mutations = Future.value();
  Future<void> _task = Future.value();
  bool _running = false;

  Future<void> accept(
    PhotoWidgetAuthority authority, {
    required bool foreground,
    bool force = false,
  }) {
    if (!_active) return Future.value();
    if (_holding && authority.mode != PhotoWidgetAccessMode.blocked) {
      final revision = _revision, owner = authority.context;
      if (owner == null || _recoveryScope == null) {
        _deferred = (authority: authority, foreground: foreground);
        return Future.value();
      }
      return photoWidgetScope(owner).then((scope) async {
        if (!_active || !_holding || _revision != revision) return;
        if (scope == _recoveryScope) {
          _deferred = (authority: authority, foreground: foreground);
        } else {
          // A different account/environment is revocation of the old scope,
          // even if its own profile is already ready. Never defer it.
          _holding = false;
          _recoveryScope = null;
          _deferred = null;
          await accept(authority, foreground: foreground, force: true);
        }
      });
    }
    if (authority.mode == PhotoWidgetAccessMode.blocked) _deferred = null;
    if (_last == authority &&
        _foreground == foreground &&
        (!force || _running)) {
      return _task;
    }
    _last = authority;
    _foreground = foreground;
    final revision = ++_revision;
    service.cancelPendingRefresh();
    bool current() => _active && _revision == revision;
    var readyForRefresh = false;
    final mutation = _mutations
        .then((_) async {
          if (!current()) return;
          if (authority.mode == PhotoWidgetAccessMode.blocked) {
            await clearCredentials();
            if (current()) {
              await store.synchronize(scope: null, expiresAt: null);
            }
          } else if (authority.context case final owner?) {
            if (authority.mode == PhotoWidgetAccessMode.expired) {
              final scope = await photoWidgetScope(owner);
              if (!current()) return;
              try {
                await store.retainExpired(
                  scope: scope,
                  expiresAt: owner.expiresAt,
                );
              } catch (_) {
                if (!current()) return;
                await clearCredentials();
                if (current()) {
                  await store.synchronize(scope: null, expiresAt: null);
                }
                return;
              }
              if (current()) {
                await expireCredentials();
              }
            } else if (authority.mode == PhotoWidgetAccessMode.ready &&
                foreground &&
                await service.available() &&
                current()) {
              readyForRefresh = (await service.synchronize()).isRight();
            } else {
              // SDK identity is known, but do not issue credentials or start a
              // second fetch while profile restoration/native background runs.
              final scope = await photoWidgetScope(owner);
              if (current()) {
                await store.synchronize(
                  scope: scope,
                  expiresAt: owner.expiresAt,
                );
              }
            }
          }
        })
        .catchError((Object _) {});
    _mutations = mutation;
    _running = true;
    final task = mutation
        .then((_) async {
          if (current() && readyForRefresh) {
            await service.refresh();
          }
        })
        .catchError((Object _) {})
        .whenComplete(() {
          if (current()) _running = false;
        });
    _task = task;
    return task;
  }

  void dispose() {
    _active = false;
    _revision++;
    service.cancelPendingRefresh();
  }
}
