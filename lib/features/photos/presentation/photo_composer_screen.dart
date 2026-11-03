import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/current_user_provider.dart';
import '../../../app/providers/photo_providers.dart';
import '../../../app/providers/photo_submission_provider.dart';
import '../../../core/error/failures.dart';
import '../domain/photo.dart';
import '../domain/photo_submission.dart';
import 'photo_failure_message.dart';
import 'photo_memory.dart';

class PhotoComposerScreen extends ConsumerStatefulWidget {
  const PhotoComposerScreen({
    required this.target,
    this.autoOpenCamera = false,
    this.onSent,
    super.key,
  });
  final PhotoTarget target;
  final bool autoOpenCamera;
  final VoidCallback? onSent;
  @override
  ConsumerState<PhotoComposerScreen> createState() =>
      _PhotoComposerScreenState();
}

class _PhotoComposerScreenState extends ConsumerState<PhotoComposerScreen>
    with WidgetsBindingObserver {
  PhotoDraft? _draft;
  Failure? _failure;
  bool _busy = false;
  bool _confirmed = false;
  String? _queueMessage;
  bool _foreground = true;
  int _revision = 0;
  bool _cameraOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(PhotoComposerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _revision++;
      evictPhotoMemory(_draft?.image);
      _draft = null;
      _busy = false;
      _confirmed = false;
      _queueMessage = null;
      _failure = const Failure.validation(message: '小队已变化，请重新选择照片');
    }
  }

  @override
  void dispose() {
    _revision++;
    evictPhotoMemory(_draft?.image);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state != AppLifecycleState.resumed) evictPhotoMemory(_draft?.image);
    setState(() => _foreground = state == AppLifecycleState.resumed);
  }

  bool get _sameAccount =>
      ref.read(currentUserProvider).asData?.value?.id == widget.target.userId;
  void _clearForAccountChange() {
    if (!mounted) return;
    _revision++;
    evictPhotoMemory(_draft?.image);
    setState(() {
      _draft = null;
      _busy = false;
      _confirmed = false;
      _queueMessage = null;
      _failure = const Failure.unauthorized(message: '账号已变化，请返回原账号');
    });
  }

  Future<void> _pick(PhotoSource source) async {
    if (_busy ||
        _confirmed ||
        !_sameAccount ||
        !_foreground ||
        !ref.read(photoSendingAvailableProvider)) {
      return;
    }
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final prepare = ref.read(prepareSquadPhotoProvider);
    final result = await prepare(target: widget.target, source: source);
    if (!mounted || revision != _revision || !_sameAccount) return;
    setState(() {
      _busy = false;
      result.match((failure) => _failure = failure, (draft) {
        if (draft != null) {
          evictPhotoMemory(_draft?.image);
          _draft = draft;
        }
      });
    });
  }

  Future<void> _send() async {
    final draft = _draft;
    if (_busy ||
        draft == null ||
        !_sameAccount ||
        !_foreground ||
        !ref.read(photoSendingAvailableProvider) ||
        !ref.read(photoSessionReadyProvider)) {
      return;
    }
    final revision = ++_revision;
    final submit = ref.read(photoSubmissionProvider(widget.target));
    setState(() {
      _busy = true;
      _failure = null;
      _confirmed = true;
      _queueMessage = null;
    });
    try {
      final result = await submit(draft);
      if (!mounted || revision != _revision || !_sameAccount) return;
      setState(() => _busy = false);
      switch (result) {
        case PhotoSubmissionSent():
          if (widget.onSent case final onSent?) {
            onSent();
          } else {
            Navigator.of(context).pop(true);
          }
        case PhotoSubmissionPending(:final failure):
          setState(() {
            _failure = failure;
            _queueMessage = failure is NetworkFailure
                ? '已保存待发，联网后会继续重试'
                : '已保存待发，可稍后使用原照片重试';
          });
        case PhotoSubmissionUnconfirmed(:final failure):
          setState(() {
            _failure = failure;
            _queueMessage = '本机保存尚未确认，请使用原照片重试';
          });
        case PhotoSubmissionRejected(:final failure):
          setState(() {
            _failure = failure;
            _confirmed = false;
          });
      }
    } catch (_) {
      if (!mounted || revision != _revision || !_sameAccount) return;
      setState(() {
        _busy = false;
        _failure = const Failure.network(message: '发送未确认，请稍后重试');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider.select((value) => value.asData?.value?.id), (
      previous,
      next,
    ) {
      if (next != widget.target.userId) _clearForAccountChange();
    });
    ref.listen(photoSessionReadyProvider, (previous, next) {
      if (!next) evictPhotoMemory(_draft?.image);
    });
    final currentId = ref.watch(currentUserProvider).asData?.value?.id;
    final ready = ref.watch(photoSessionReadyProvider);
    final available = ref.watch(photoSendingAvailableProvider);
    final sameAccount = currentId == widget.target.userId;
    if (widget.autoOpenCamera &&
        !_cameraOpened &&
        sameAccount &&
        ready &&
        available) {
      _cameraOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pick(PhotoSource.camera);
      });
    }
    if (sameAccount && ready && available) {
      ref.watch(photoSubmissionProvider(widget.target));
    }
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.target.replyToMessageId == null ? '发照片' : '回拍照片'),
      ),
      body: SafeArea(
        child: !sameAccount || !ready
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('请返回原账号并联网登录后继续'),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          '仅「${widget.target.squadName}」成员可见',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        if (draft != null && _foreground)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 420),
                              child: Image.memory(
                                draft.image.bytes,
                                width: double.infinity,
                                key: ValueKey(draft.clientNonce),
                                fit: BoxFit.contain,
                                gaplessPlayback: false,
                                excludeFromSemantics: false,
                                semanticLabel: '待发送照片',
                                errorBuilder: (_, _, _) => const SizedBox(
                                  height: 180,
                                  child: Center(child: Text('照片预览失败，请重新选择')),
                                ),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 220,
                            child: Center(
                              child: Text(
                                _foreground ? '拍下小队里的这一刻' : '照片预览已隐藏',
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy || _confirmed || !available
                                  ? null
                                  : () => _pick(PhotoSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('拍一张'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy || _confirmed || !available
                                  ? null
                                  : () => _pick(PhotoSource.library),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('从相册选择'),
                            ),
                          ],
                        ),
                        if (!available)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text('当前版本的照片服务暂不可用'),
                          ),
                        if (_failure != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              photoFailureMessage(_failure!),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (_queueMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_queueMessage!),
                          ),
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy || draft == null || !available
                            ? null
                            : _send,
                        child: Text(
                          _busy ? '正在处理…' : '发到「${widget.target.squadName}」',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
