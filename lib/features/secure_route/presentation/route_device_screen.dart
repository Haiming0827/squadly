import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/current_user_provider.dart';
import '../data/route_crypto.dart';
import '../domain/route_fingerprint.dart';
import 'route_reader_provider.dart';

/// Shows the key fingerprint for an out-of-band comparison with teammates.
/// Registering a public key never uploads the private key or any route.
final class RouteDeviceScreen extends ConsumerStatefulWidget {
  const RouteDeviceScreen({super.key});

  @override
  ConsumerState<RouteDeviceScreen> createState() => _RouteDeviceScreenState();
}

final class _RouteDeviceScreenState extends ConsumerState<RouteDeviceScreen> {
  RouteDeviceKey? _device;
  String? _fingerprint;
  String? _error;
  bool _busy = false;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final userId = ref.read(currentUserProvider).value?.id;
    if (userId == null) return;
    try {
      final key = await ref
          .read(routeDeviceKeyStoreProvider)
          .loadExisting(userId: userId);
      if (key == null || !mounted) return;
      final fingerprint = await RouteFingerprint.ofPublicKey(
        key.publicKeyBase64,
      );
      if (!mounted) return;
      setState(() {
        _device = key;
        _fingerprint = fingerprint;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '本机路线密钥无法读取；不会自动替换');
    }
  }

  Future<void> _register() async {
    final userId = ref.read(currentUserProvider).value?.id;
    if (userId == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final device = await ref
          .read(routeDeviceKeyStoreProvider)
          .loadOrCreate(userId: userId);
      await ref
          .read(routeKeyDirectoryProvider)
          .registerDevice(
            RouteRecipient(
              userId: userId,
              deviceId: device.deviceId,
              publicKeyBase64: device.publicKeyBase64,
            ),
          );
      final fingerprint = await RouteFingerprint.ofPublicKey(
        device.publicKeyBase64,
      );
      if (!mounted) return;
      setState(() {
        _device = device;
        _fingerprint = fingerprint;
        _registered = true;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '设备登记失败，请检查网络或稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('路线设备')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('精确路线只会加密给已登记的队友设备。发布前，请与队友当面或通过可信渠道核对设备指纹。'),
            const SizedBox(height: 20),
            if (_device != null) ...[
              Text('本机设备指纹', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(_fingerprint ?? '正在计算…'),
              const SizedBox(height: 8),
              Text(_registered ? '此设备已登记' : '本机已有密钥，可重新登记'),
              const SizedBox(height: 20),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _register,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(_busy ? '正在登记…' : '登记此设备以接收路线'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            const Text('换机或重装可能使旧卡片路线无法解密；不要把本机私钥或验证码发给任何人。'),
          ],
        ),
      ),
    );
  }
}
