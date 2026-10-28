import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../app/providers/photo_widget_providers.dart';
import '../../../core/error/failures.dart';
import '../domain/photo_widget.dart';
import 'widget_failure_message.dart';

class PhotoWidgetSettingsScreen extends ConsumerStatefulWidget {
  const PhotoWidgetSettingsScreen({
    required this.squadId,
    required this.squadName,
    super.key,
  });
  final String squadId;
  final String squadName;

  @override
  ConsumerState<PhotoWidgetSettingsScreen> createState() =>
      _PhotoWidgetSettingsState();
}

class _PhotoWidgetSettingsState extends ConsumerState<PhotoWidgetSettingsScreen>
    with WidgetsBindingObserver {
  PhotoWidgetSnapshot? _snapshot;
  int? _installed;
  bool _busy = true;
  bool _available = false;
  String? _error;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_read);
  }

  @override
  void dispose() {
    _revision++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _read();
  }

  Future<void> _read() async {
    final revision = ++_revision;
    final owner = ref.read(photoWidgetContextProvider);
    final service = ref.read(photoWidgetServiceProvider);
    if (mounted) setState(() => _busy = true);
    final available = await service.available();
    final result = available ? await service.read() : null;
    int? installed;
    if (available) {
      try {
        installed = await service.store.installedCount();
      } catch (_) {
        // Unknown is distinct from zero installed system configurations.
      }
    }
    if (!mounted ||
        revision != _revision ||
        ref.read(photoWidgetContextProvider) != owner) {
      return;
    }
    setState(() {
      _busy = false;
      _available = available;
      _installed = installed;
      _snapshot = result?.getRight().toNullable();
      final failure = result?.getLeft().toNullable();
      _error = failure == null ? null : widgetFailureMessage(failure);
    });
  }

  Future<void> _change(
    Future<Either<Failure, PhotoWidgetSnapshot>> Function() action,
  ) async {
    if (_busy) return;
    final revision = ++_revision;
    final owner = ref.read(photoWidgetContextProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await action();
    if (!mounted ||
        revision != _revision ||
        ref.read(photoWidgetContextProvider) != owner) {
      return;
    }
    setState(() {
      _busy = false;
      result.match(
        (failure) => _error = widgetFailureMessage(failure),
        (value) => _snapshot = value,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(photoWidgetContextProvider);
    ref.listen(photoWidgetContextProvider, (previous, next) {
      _revision++;
      setState(() {
        _snapshot = null;
        _error = null;
        _busy = false;
      });
      Future.microtask(_read);
    });
    final state = _snapshot;
    final bound =
        owner != null &&
        state?.binding?.squadId == widget.squadId &&
        state?.binding?.scope == state?.lease?.scope;
    final service = ref.read(photoWidgetServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('小队桌面组件')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.squadName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            if (!_busy && !_available) const Text('当前设备或版本暂不支持桌面组件'),
            if (_available) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.widgets_outlined),
                title: Text(bound ? '已绑定这个小队' : '尚未绑定这个小队'),
                subtitle: Text(
                  _installed == null
                      ? '系统组件数量暂无法确认'
                      : _installed == 0
                      ? '桌面上尚未检测到小队组件'
                      : '已检测到 $_installed 个桌面组件',
                ),
              ),
              if (!bound)
                FilledButton(
                  onPressed: _busy || owner == null
                      ? null
                      : () => _change(() => service.bind(widget.squadId)),
                  child: Text(state?.binding == null ? '绑定这个小队' : '改为绑定这个小队'),
                ),
              if (!bound && state?.binding != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('更换绑定会清除原组件照片，并关闭照片预览'),
                ),
              if (bound) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('在桌面显示小队照片'),
                  subtitle: const Text('开启后，拿到这台设备的人也可能看到照片'),
                  value: state!.binding!.previewEnabled,
                  onChanged: _busy
                      ? null
                      : (value) =>
                            _change(() => service.setPreview(state, value)),
                ),
                Text(switch (state.display) {
                  PhotoWidgetDisplay.photo => '照片已交给系统更新，桌面显示时间由 iOS 决定',
                  PhotoWidgetDisplay.expired => '照片预览已到期',
                  PhotoWidgetDisplay.unavailable => '照片暂不可用',
                  PhotoWidgetDisplay.hidden => '照片预览已关闭',
                  PhotoWidgetDisplay.empty => '还没有可显示的照片',
                  _ => '请重新登录后更新组件',
                }),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _change(
                          () => service.refresh(
                            expectedBinding: state.binding!.id,
                          ),
                        ),
                  child: const Text('更新组件'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _change(() async {
                          final result = await service.unbind(state);
                          final failure = result.getLeft().toNullable();
                          if (failure != null) return left(failure);
                          return service.read();
                        }),
                  child: const Text('解除绑定'),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                '添加到主屏幕',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('长按主屏幕空白处 → 编辑 → 添加小组件 → 搜索「Squadly」'),
              TextButton(
                onPressed: _busy ? null : _read,
                child: const Text('重新检测桌面组件'),
              ),
            ],
            if (owner == null) const Text('请联网登录后绑定小队组件'),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
