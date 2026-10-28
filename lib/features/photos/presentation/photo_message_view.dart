import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/current_user_provider.dart';
import '../../../app/providers/photo_providers.dart';
import '../../../core/error/failures.dart';
import '../domain/photo.dart';
import 'photo_failure_message.dart';
import 'photo_memory.dart';

/// Displays a short-lived, authenticated copy. No message read cursor writes.
class PhotoMessageView extends ConsumerStatefulWidget {
  const PhotoMessageView({
    required this.squadId,
    required this.messageId,
    required this.authorId,
    required this.photo,
    required this.canRead,
    required this.onChanged,
    this.onReplyPhoto,
    this.onDisplayChanged,
    super.key,
  });
  final String squadId;
  final String messageId;
  final String authorId;
  final PhotoAttachment photo;
  final bool canRead;
  final VoidCallback onChanged;
  final VoidCallback? onReplyPhoto;

  /// True only after decoded pixels have painted; never advances a cursor.
  final ValueChanged<bool>? onDisplayChanged;
  @override
  ConsumerState<PhotoMessageView> createState() => _PhotoMessageViewState();
}

class _PhotoMessageViewState extends ConsumerState<PhotoMessageView>
    with WidgetsBindingObserver {
  PhotoImage? _image;
  Failure? _failure;
  bool _busy = false;
  bool _foreground = true;
  bool _revokedLocally = false;
  int _generation = 0;
  String? _account;
  Timer? _lease;
  bool _scheduled = false;
  bool _wasCurrent = false;
  bool _displayed = false;
  bool _paintScheduled = false;

  void _displayChanged(bool value) {
    if (_displayed == value) return;
    _displayed = value;
    widget.onDisplayChanged?.call(value);
  }

  void _schedulePainted() {
    if (_paintScheduled || _displayed) return;
    _paintScheduled = true;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paintScheduled = false;
      if (mounted &&
          generation == _generation &&
          _readable &&
          _image != null &&
          _account == ref.read(currentUserProvider).asData?.value?.id) {
        _displayChanged(true);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (!current) {
      _clear();
      _busy = false;
    }
    if (current && !_wasCurrent) _scheduleLoad();
    _wasCurrent = current;
  }

  @override
  void didUpdateWidget(PhotoMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId ||
        oldWidget.squadId != widget.squadId) {
      _clear();
      _revokedLocally = false;
      _failure = null;
      _busy = false;
      _scheduleLoad();
    } else if (!widget.canRead || widget.photo.isRevoked) {
      _clear();
      _busy = false;
    } else if (!oldWidget.canRead && widget.canRead) {
      _scheduleLoad();
    }
  }

  @override
  void dispose() {
    _clear();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    _foreground = state == AppLifecycleState.resumed;
    setState(() {
      _clear();
      _busy = false;
    });
    if (_foreground) _scheduleLoad();
  }

  void _clear() {
    _displayChanged(false);
    _generation++;
    _lease?.cancel();
    _lease = null;
    evictPhotoMemory(_image);
    _image = null;
  }

  bool get _revoked => widget.photo.isRevoked || _revokedLocally;
  bool get _readable =>
      !_revoked &&
      widget.canRead &&
      _foreground &&
      ref.read(photoSessionReadyProvider) &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  void _scheduleLoad() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && _readable && !_busy && _image == null) unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (_busy || !_readable) return;
    final user = ref.read(currentUserProvider).asData?.value?.id;
    if (user == null) return;
    _account = user;
    final repository = ref.read(photoRepositoryProvider);
    final generation = ++_generation;
    setState(() {
      evictPhotoMemory(_image);
      _image = null;
      _busy = true;
      _failure = null;
    });
    try {
      final result = await repository.load(
        squadId: widget.squadId,
        messageId: widget.messageId,
      );
      if (!mounted ||
          generation != _generation ||
          !_readable ||
          ref.read(currentUserProvider).asData?.value?.id != user) {
        return;
      }
      setState(() {
        _busy = false;
        result.match((failure) => _failure = failure, (image) {
          _image = image;
          // Bound stale membership/revocation exposure without downloading
          // every visible image repeatedly in the background.
          _lease?.cancel();
          _lease = Timer(const Duration(minutes: 1), () {
            if (!mounted) return;
            setState(() {
              _clear();
              _failure = const Failure.server(message: '照片预览已到期，点按重新加载');
            });
          });
        });
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _busy = false;
        _failure = const Failure.network(message: '照片加载失败，请稍后重试');
      });
    }
  }

  Future<void> _revoke() async {
    if (_busy ||
        !_readable ||
        ref.read(currentUserProvider).asData?.value?.id != widget.authorId) {
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤回这张照片？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤回'),
          ),
        ],
      ),
    );
    if (!mounted ||
        yes != true ||
        !_readable ||
        ref.read(currentUserProvider).asData?.value?.id != widget.authorId) {
      return;
    }
    _clear();
    final generation = _generation;
    final repository = ref.read(photoRepositoryProvider);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final result = await repository.revoke(
        squadId: widget.squadId,
        messageId: widget.messageId,
      );
      if (!mounted || generation != _generation || !_readable) return;
      setState(() {
        _busy = false;
        result.match(
          (failure) => _failure = failure,
          (_) => _revokedLocally = true,
        );
      });
      if (_revokedLocally) widget.onChanged();
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _busy = false;
        _failure = const Failure.network(message: '撤回未确认，请稍后重试');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider.select((v) => v.asData?.value?.id), (
      previous,
      next,
    ) {
      if (previous != next) {
        setState(() {
          _clear();
          _busy = false;
          _account = null;
        });
      }
    });
    ref.listen(photoSessionReadyProvider, (previous, next) {
      if (!next) {
        setState(() {
          _clear();
          _busy = false;
        });
      }
    });
    final user = ref.watch(currentUserProvider).asData?.value?.id;
    final ready = ref.watch(photoSessionReadyProvider);
    final readable =
        ready && widget.canRead && _foreground && !_revoked && _wasCurrent;
    final image = readable && _account == user ? _image : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: Image.memory(
                image.bytes,
                width: double.infinity,
                semanticLabel: '小队照片',
                fit: BoxFit.contain,
                gaplessPlayback: false,
                frameBuilder: (_, child, frame, synchronous) {
                  if (frame != null || synchronous) _schedulePainted();
                  return child;
                },
                errorBuilder: (_, _, _) {
                  _displayChanged(false);
                  return const Text('照片暂时无法显示');
                },
              ),
            ),
          )
        else if (_revoked)
          const Padding(padding: EdgeInsets.all(20), child: Text('照片已撤回'))
        else if (!readable)
          const Padding(padding: EdgeInsets.all(20), child: Text('照片需联网登录后查看'))
        else if (_busy)
          const Padding(
            padding: EdgeInsets.all(20),
            child: LinearProgressIndicator(),
          )
        else
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.photo_outlined),
            label: Text(
              _failure == null ? '加载照片' : photoFailureMessage(_failure!),
            ),
          ),
        if (!_revoked && readable)
          Wrap(
            spacing: 8,
            children: [
              if (widget.onReplyPhoto != null)
                TextButton.icon(
                  onPressed: _busy ? null : widget.onReplyPhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('回拍一张'),
                ),
              if (user == widget.authorId)
                TextButton(
                  onPressed: _busy ? null : _revoke,
                  child: const Text('撤回照片'),
                ),
            ],
          ),
      ],
    );
  }
}
