import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/photo_widget_providers.dart';
import '../../photos/domain/photo.dart';
import '../domain/photo_widget.dart';
import 'widget_failure_message.dart';

/// The app composes the camera destination; this feature only resolves the
/// fixed authenticated target. Resolving never advances conversation reads.
class PhotoWidgetEntryScreen extends ConsumerStatefulWidget {
  const PhotoWidgetEntryScreen({
    required this.entry,
    required this.cameraBuilder,
    super.key,
  });
  final PhotoWidgetEntry? entry;
  final Widget Function(PhotoTarget) cameraBuilder;
  @override
  ConsumerState<PhotoWidgetEntryScreen> createState() =>
      _PhotoWidgetEntryState();
}

class _PhotoWidgetEntryState extends ConsumerState<PhotoWidgetEntryScreen> {
  PhotoTarget? _target;
  String? _error;
  int _revision = 0;
  bool _opened = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(_resolve);
  }

  @override
  void didUpdateWidget(PhotoWidgetEntryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry != widget.entry) {
      _target = null;
      _error = null;
      Future.microtask(_resolve);
    }
  }

  Future<void> _resolve() async {
    final revision = ++_revision;
    final entry = widget.entry;
    if (entry == null) {
      if (mounted) setState(() => _error = '这个组件链接无效，请从桌面重新打开');
      return;
    }
    final result = await ref.read(photoWidgetServiceProvider).resolve(entry);
    if (!mounted || revision != _revision) return;
    setState(
      () => result.match((failure) => _error = widgetFailureMessage(failure), (
        target,
      ) {
        _opened = true;
        _target = target;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(photoWidgetContextProvider, (previous, next) {
      _revision++;
      if (!_opened && next != null) {
        setState(() {
          _target = null;
          _error = null;
        });
        Future.microtask(_resolve);
        return;
      }
      setState(() {
        _target = null;
        _error = '登录会话已变化，请从桌面重新打开';
      });
    });
    final target = _target;
    if (target != null) return widget.cameraBuilder(target);
    return Scaffold(
      appBar: AppBar(title: const Text('小队回拍')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error == null
              ? const CircularProgressIndicator()
              : Text(_error!),
        ),
      ),
    );
  }
}
