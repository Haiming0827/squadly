import 'package:fpdart/fpdart.dart';

import '../../../core/error/failures.dart';
import '../../conversation/domain/photo_head.dart';
import '../../conversation/domain/timeline_entry.dart';
import '../../photos/domain/photo.dart';
import '../../squad/domain/entities/squad.dart';
import 'photo_widget.dart';

typedef WidgetSquadLookup = Future<Either<Failure, Squad>> Function(
  PhotoWidgetContext context,
  String squadId,
);
typedef WidgetLatestPhoto = Future<Either<Failure, PhotoHead>> Function(
  PhotoWidgetContext context,
  String squadId,
);
typedef WidgetFindPhoto = Future<Either<Failure, TimelineEntry?>> Function(
  PhotoWidgetContext context,
  String squadId,
  String messageId,
);
typedef WidgetLoadPhoto = Future<Either<Failure, PhotoImage>> Function(
  PhotoWidgetContext context,
  String squadId,
  String messageId,
);

/// Coordinates account-bound domain operations. The platform store makes the
/// last binding/session check atomic with the write; no read-cursor dependency.
final class PhotoWidgetService {
  PhotoWidgetService({
    required this.store,
    required this.context,
    required this.squad,
    required this.latest,
    required this.find,
    required this.load,
    this.onSnapshot,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final PhotoWidgetStore store;
  final PhotoWidgetContext? Function() context;
  final WidgetSquadLookup squad;
  final WidgetLatestPhoto latest;
  final WidgetFindPhoto find;
  final WidgetLoadPhoto load;
  final void Function(PhotoWidgetSnapshot)? onSnapshot;
  final DateTime Function() clock;
  bool _active = true;
  int _refreshRevision = 0;
  final _suppressed = <(String, String, String)>{};
  bool _hidden(PhotoWidgetContext owner, String squadId, String messageId) =>
      _suppressed.contains((
        '${owner.environmentId}:${owner.userId}',
        squadId,
        messageId,
      ));

  /// Fence foreground and native work before an explicit hide/report request.
  /// Server confirmation may be delayed; do not briefly restore those pixels.
  Future<void> suppressPhoto(String squadId, String messageId) async {
    final owner = _current();
    if (owner == null) return;
    final scope = '${owner.environmentId}:${owner.userId}';
    _suppressed.removeWhere((value) => value.$1 != scope);
    _suppressed.add((scope, squadId, messageId));
    _refreshRevision++;
    final state = (await read()).getRight().toNullable();
    if (state != null &&
        _same(owner) &&
        _owned(state) &&
        state.binding!.squadId == squadId) {
      try {
        await store.invalidate(expected: state, failed: true);
      } catch (_) {
        /* Store remains bounded by its existing lease. */
      }
    }
  }

  Future<void> _syncTail = Future.value();
  static const _changed = Failure.unauthorized(message: '账号或组件已变化，请重新打开');
  static const _unavailable = Failure.server(message: '桌面组件暂不可用，请稍后重试');
  void cancelPendingRefresh() => _refreshRevision++;

  void dispose() {
    _active = false;
    _refreshRevision++;
  }

  PhotoWidgetContext? _current() {
    final value = context();
    return value != null &&
            value.userId.isNotEmpty &&
            value.environmentId.isNotEmpty &&
            clock().isBefore(value.expiresAt)
        ? value
        : null;
  }

  bool _same(PhotoWidgetContext? value) => _active && _current() == value;

  Future<bool> available() async {
    try {
      return _active && await store.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<Either<Failure, PhotoWidgetSnapshot>> synchronize({
    bool reset = false,
  }) {
    final next = _syncTail.then<Either<Failure, PhotoWidgetSnapshot>>(
      (_) => _guard<PhotoWidgetSnapshot>(() async {
        if (!_active) return left(_changed);
        if (reset) await store.synchronize(scope: null, expiresAt: null);
        final owner = _current();
        final scope = owner == null ? null : await photoWidgetScope(owner);
        if (!_same(owner)) return left(_changed);
        final value = await store.synchronize(
          scope: scope,
          expiresAt: owner?.expiresAt,
        );
        return _same(owner) ? right(value) : left(_changed);
      }),
    );
    _syncTail = next.then((_) {});
    return next;
  }

  Future<Either<Failure, PhotoWidgetSnapshot>> read() => _guard(() async {
    final owner = _current();
    final sync = await synchronize();
    if (sync.isLeft()) return sync;
    if (!_same(owner)) return left(_changed);
    final value = await store.read();
    return _same(owner) ? right(value) : left(_changed);
  });
  Future<Either<Failure, PhotoWidgetSnapshot>> bind(String squadId) =>
      _guard(() async {
        final owner = _current();
        if (owner == null) return left(_changed);
        final sync = await synchronize();
        final state = sync.getRight().toNullable();
        if (state?.lease == null) {
          return left(sync.getLeft().getOrElse(() => _changed));
        }
        final allowed = await squad(owner, squadId);
        if (!_same(owner)) return left(_changed);
        final target = allowed.getRight().toNullable();
        if (target == null) {
          return left(allowed.getLeft().getOrElse(() => _changed));
        }
        if (target.id != squadId) return left(_changed);
        final value = await store.bind(
          lease: state!.lease!,
          squadId: squadId,
          squadName: target.name,
        );
        return _same(owner) ? right(value) : left(_changed);
      });
  Future<Either<Failure, PhotoWidgetSnapshot>> setPreview(
    PhotoWidgetSnapshot expected,
    bool enabled,
  ) => _guard(() async {
    _refreshRevision++;
    final owner = _current();
    if (owner == null || !await _expectedCurrent(expected, owner)) {
      return left(_changed);
    }
    if (enabled) {
      final access = await squad(owner, expected.binding!.squadId);
      if (!_same(owner)) return left(_changed);
      if (access.isLeft()) {
        return left(access.getLeft().getOrElse(() => _changed));
      }
    }
    final value = await store.setPreview(expected: expected, enabled: enabled);
    if (!_same(owner)) return left(_changed);
    return enabled
        ? await refresh(expectedBinding: value.binding!.id)
        : right(value);
  });
  Future<Either<Failure, PhotoWidgetSnapshot>> refresh({
    String? expectedBinding,
  }) => _guard(() async {
    final revision = ++_refreshRevision;
    final owner = _current();
    if (owner == null) return left(_changed);
    final sync = await synchronize();
    final state = sync.getRight().toNullable();
    if (state == null) return sync;
    if (!_owned(state) ||
        (expectedBinding != null && state.binding!.id != expectedBinding)) {
      return left(_changed);
    }
    if (!state.binding!.previewEnabled) return right(state);
    final id = state.binding!.squadId;
    final access = await squad(owner, id);
    if (!_same(owner) || revision != _refreshRevision) return left(_changed);
    if (access.isLeft()) {
      await store.invalidate(expected: state, failed: true);
      return left(access.getLeft().getOrElse(() => _changed));
    }
    final page = await latest(owner, id);
    if (!_same(owner) || revision != _refreshRevision) return left(_changed);
    final head = page.getRight().toNullable();
    if (head == null) {
      await store.invalidate(expected: state, failed: true);
      return left(page.getLeft().getOrElse(() => _unavailable));
    }
    if (!validPhotoHeadRevision(head.revision) ||
        (head.photo != null &&
            (_hidden(owner, id, head.photo!.id) ||
                head.photo!.photo?.isHidden == true)) ||
        (head.photo != null &&
            (head.revision == '0' || !_photo(head.photo!, id)))) {
      await store.invalidate(expected: state, failed: true);
      return left(_unavailable);
    }
    if (head.photo == null) {
      return right(await store.applyHead(expected: state, head: head));
    }
    final message = head.photo!;
    final result = await load(owner, id, message.id);
    if (!_same(owner) || revision != _refreshRevision) return left(_changed);
    final image = result.getRight().toNullable();
    if (image == null) {
      await store.invalidate(expected: state, failed: true);
      return left(result.getLeft().getOrElse(() => _unavailable));
    }
    // Downloading pixels may race publication/revocation. Validate the atomic
    // server head again before granting a fresh display lease.
    final confirmation = await latest(owner, id);
    if (!_same(owner) || revision != _refreshRevision) return left(_changed);
    final confirmed = confirmation.getRight().toNullable();
    if (confirmed?.revision != head.revision ||
        confirmed?.photo?.id != message.id) {
      await store.invalidate(expected: state, failed: true);
      return left(confirmation.getLeft().getOrElse(() => _unavailable));
    }
    final value = await store.applyHead(
      expected: state,
      head: head,
      image: image,
    );
    return _same(owner) && revision == _refreshRevision
        ? right(value)
        : left(_changed);
  });
  Future<Either<Failure, PhotoTarget>> resolve(PhotoWidgetEntry entry) =>
      _guard(() async {
        final owner = _current();
        if (owner == null) return left(_changed);
        final scope = await photoWidgetScope(owner);
        if (!_same(owner) || scope != entry.scope) return left(_changed);
        final sync = await synchronize();
        final state = sync.getRight().toNullable();
        if (state?.binding == null ||
            state!.binding!.scope != scope ||
            state.binding!.id != entry.bindingId ||
            state.binding!.squadId != entry.squadId) {
          return left(
            const Failure.permissionDenied(message: '这个组件绑定已变化，请从桌面重新打开'),
          );
        }
        final access = await squad(owner, entry.squadId);
        if (!_same(owner)) return left(_changed);
        final target = access.getRight().toNullable();
        if (target == null) {
          return left(access.getLeft().getOrElse(() => _changed));
        }
        if (target.id != entry.squadId) return left(_changed);
        if (entry.messageId != null) {
          final parent = await find(owner, entry.squadId, entry.messageId!);
          if (!_same(owner)) return left(_changed);
          final photo = parent.getRight().toNullable();
          if (photo == null ||
              photo.id != entry.messageId ||
              _hidden(owner, entry.squadId, photo.id) ||
              !_photo(photo, entry.squadId)) {
            return left(
              parent.getLeft().getOrElse(
                () => const Failure.notFound(message: '原照片已无法回拍，请返回小队查看'),
              ),
            );
          }
        }
        return right(
          PhotoTarget(
            userId: owner.userId,
            squadId: target.id,
            squadName: target.name,
            replyToMessageId: entry.messageId,
          ),
        );
      });
  Future<Either<Failure, Unit>> unbind(PhotoWidgetSnapshot expected) =>
      _guard(() async {
        final owner = _current();
        if (owner == null || !await _expectedCurrent(expected, owner)) {
          return left(_changed);
        }
        await store.unbind(expected);
        return _same(owner) ? right(unit) : left(_changed);
      });
  bool _owned(PhotoWidgetSnapshot state) =>
      state.binding != null &&
      state.lease != null &&
      state.binding!.scope == state.lease!.scope &&
      clock().isBefore(state.lease!.expiresAt);

  Future<bool> _expectedCurrent(
    PhotoWidgetSnapshot expected,
    PhotoWidgetContext owner,
  ) async {
    final current = (await synchronize()).getRight().toNullable();
    return _same(owner) &&
        current != null &&
        _owned(current) &&
        current.binding!.id == expected.binding?.id &&
        current.lease!.generation == expected.lease?.generation &&
        current.lease!.scope == expected.lease?.scope;
  }

  bool _photo(TimelineEntry e, String squadId) =>
      e.squadId == squadId &&
      e.planId == null &&
      e.kind == TimelineEntryKind.photo &&
      e.photo?.isRevoked == false &&
      e.photo?.isHidden == false;
  Future<Either<Failure, T>> _guard<T>(
    Future<Either<Failure, T>> Function() work,
  ) async {
    try {
      final result = await work();
      final value = result.getRight().toNullable();
      if (_active && value is PhotoWidgetSnapshot) {
        try {
          onSnapshot?.call(value);
        } catch (_) {
          /* Optional observer only. */
        }
      }
      return result;
    } catch (_) {
      return left(_unavailable);
    }
  }
}
