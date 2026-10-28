import 'package:flutter/services.dart';

import '../domain/photo_widget.dart';

/// Ephemeral main-app input. Never persist in shared widget storage or logs.
final class PhotoBackgroundCredentialMaterial {
  const PhotoBackgroundCredentialMaterial({
    required this.environmentId,
    required this.region,
    required this.userId,
    required this.gateway,
    required this.accessToken,
    required this.expiresAt,
  });
  final String environmentId;
  final String region;
  final String userId;
  final Uri gateway;
  final String accessToken;
  final DateTime expiresAt;
  @override
  String toString() => 'PhotoBackgroundCredentialMaterial(<redacted>)';
}

abstract interface class PhotoBackgroundCredentialBridge {
  Future<String> prepare(PhotoWidgetSnapshot expected);
  Future<void> commit(
    String ticket,
    PhotoBackgroundCredentialMaterial material,
  );
  Future<void> cancel(String ticket);
  Future<void> clear();
}

final class NativePhotoBackgroundCredentialBridge
    implements PhotoBackgroundCredentialBridge {
  const NativePhotoBackgroundCredentialBridge([
    this.channel = const MethodChannel('squadly/photo-background'),
  ]);
  final MethodChannel channel;
  @override
  Future<String> prepare(PhotoWidgetSnapshot expected) async {
    final binding = expected.binding, lease = expected.lease;
    if (binding == null || lease == null || binding.scope != lease.scope) {
      throw const FormatException('Invalid credential context');
    }
    final ticket = await channel.invokeMethod<String>('prepare', {
      'bindingId': binding.id,
      'generation': lease.generation,
    });
    if (ticket == null || !widgetUuid(ticket)) {
      throw const FormatException('Invalid credential ticket');
    }
    return ticket;
  }

  @override
  Future<void> commit(
    String ticket,
    PhotoBackgroundCredentialMaterial material,
  ) async {
    final accepted = await channel.invokeMethod<bool>('commit', {
      'ticket': ticket,
      'environmentId': material.environmentId,
      'region': material.region,
      'userId': material.userId,
      'gateway': material.gateway.toString(),
      'accessToken': material.accessToken,
      'expiresAt': material.expiresAt.toUtc().millisecondsSinceEpoch,
    });
    if (accepted != true) {
      throw const FormatException('Credential was not accepted');
    }
  }

  @override
  Future<void> cancel(String ticket) async {
    await channel.invokeMethod<bool>('cancel', {'ticket': ticket});
  }

  @override
  Future<void> clear() async {
    await channel.invokeMethod<bool>('clear');
  }
}

/// Coalesces repeated snapshots without keeping token material in controller
/// state. Native tickets also fence the last check/write across account changes.
final class PhotoBackgroundCredentialController {
  PhotoBackgroundCredentialController({
    required this.bridge,
    required this.read,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final PhotoBackgroundCredentialBridge bridge;
  final Future<PhotoBackgroundCredentialMaterial?> Function() read;
  final DateTime Function() clock;
  int _revision = 0;
  bool _active = true;
  String? _key;
  Future<void> _task = Future.value();

  Future<void> accept(PhotoWidgetSnapshot snapshot) {
    if (!_active) return Future.value();
    final binding = snapshot.binding, lease = snapshot.lease;
    final enabled =
        binding != null &&
        lease != null &&
        binding.previewEnabled &&
        binding.scope == lease.scope &&
        clock().isBefore(lease.expiresAt) &&
        snapshot.display != PhotoWidgetDisplay.unavailable;
    final key = enabled
        ? '${binding.id}:${lease.generation}:${lease.scope}:${lease.expiresAt.toUtc().millisecondsSinceEpoch}'
        : 'disabled';
    if (key == _key) return _task;
    _key = key;
    final revision = ++_revision;
    return _task = _accept(snapshot, revision, enabled);
  }

  bool _same(int revision) => _active && revision == _revision;
  Future<void> _accept(
    PhotoWidgetSnapshot snapshot,
    int revision,
    bool enabled,
  ) async {
    String? ticket;
    try {
      if (!enabled) {
        await bridge.clear();
        return;
      }
      ticket = await bridge.prepare(snapshot);
      if (!_same(revision)) return;
      final material = await read();
      if (!_same(revision) ||
          material == null ||
          !clock().isBefore(material.expiresAt)) {
        return;
      }
      await bridge.commit(ticket, material);
      ticket = null;
    } catch (_) {
      // Credential failure cannot undo a confirmed foreground photo update.
      if (_same(revision)) _key = null;
    } finally {
      if (ticket != null) {
        try {
          await bridge.cancel(ticket);
        } catch (_) {
          /* Fail closed natively. */
        }
        if (_same(revision)) _key = null;
      }
    }
  }

  Future<void> reset() {
    _revision++;
    _key = null;
    return _clear();
  }

  Future<void> dispose() {
    _active = false;
    _revision++;
    _key = null;
    return _clear();
  }

  Future<void> _clear() async {
    try {
      await bridge.clear();
    } catch (_) {
      /* Native context still gates use. */
    }
  }
}
