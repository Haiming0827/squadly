import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/photo_widget.dart';
import 'photo_background_credentials.dart';

final class PhotoBackgroundRenewalRequest {
  const PhotoBackgroundRenewalRequest(this.ticket, this.scope, this.remaining);
  final String ticket;
  final String scope;
  final Duration remaining;
  static PhotoBackgroundRenewalRequest? parse(Object? raw) {
    if (raw is! Map ||
        raw.length != 3 ||
        !raw.keys.toSet().containsAll({'ticket', 'scope', 'remainingMs'})) {
      return null;
    }
    final ticket = raw['ticket'], scope = raw['scope'], ms = raw['remainingMs'];
    if (ticket is! String ||
        !widgetUuid(ticket) ||
        scope is! String ||
        !widgetScope(scope) ||
        ms is! int ||
        ms < 1 ||
        ms > 8000) {
      return null;
    }
    return PhotoBackgroundRenewalRequest(
      ticket,
      scope,
      Duration(milliseconds: ms),
    );
  }
}

/// Only access-token material is returned to the main native app. The callback
/// receives an invalidation/deadline guard for queued SDK work and late results.
final class PhotoBackgroundRenewalController {
  PhotoBackgroundRenewalController({
    required this.read,
    required this.hold,
    required this.release,
    this.channel = const MethodChannel('squadly/photo-renewal'),
  });
  final Future<PhotoBackgroundCredentialMaterial?> Function(
    PhotoBackgroundRenewalRequest request,
    bool Function() isCurrent,
  )
  read;
  final void Function(String scope) hold;
  final Future<void> Function() release;
  final MethodChannel channel;
  bool _active = true;
  bool _busy = false;
  int _epoch = 0;

  Future<void> start() async {
    channel.setMethodCallHandler(_handle);
    try {
      await channel.invokeMethod<bool>('ready');
    } catch (_) {
      /* Native may be unavailable. */
    }
  }

  void invalidate() => _epoch++;
  Future<void> dispose() async {
    _active = false;
    invalidate();
    channel.setMethodCallHandler(null);
    try {
      await channel.invokeMethod<bool>('close');
    } catch (_) {
      /* No native context. */
    }
  }

  Future<Object?> _handle(MethodCall call) async {
    final request = PhotoBackgroundRenewalRequest.parse(call.arguments);
    if (!_active || _busy || call.method != 'renew' || request == null) {
      return false;
    }
    _busy = true;
    final epoch = ++_epoch, watch = Stopwatch()..start();
    bool current() =>
        _active && epoch == _epoch && watch.elapsed < request.remaining;
    hold(request.scope);
    try {
      return await (() async {
        final material = await read(request, current);
        if (!current() ||
            material == null ||
            !DateTime.now().isBefore(material.expiresAt)) {
          return false;
        }
        return await channel.invokeMethod<bool>('commit', {
              'ticket': request.ticket,
              'environmentId': material.environmentId,
              'region': material.region,
              'userId': material.userId,
              'gateway': material.gateway.toString(),
              'accessToken': material.accessToken,
              'expiresAt': material.expiresAt.toUtc().millisecondsSinceEpoch,
            }) ==
            true;
      })().timeout(request.remaining, onTimeout: () => false);
    } catch (_) {
      return false;
    } finally {
      if (epoch == _epoch) invalidate();
      _busy = false;
      watch.stop();
      unawaited(release().catchError((Object _) {}));
    }
  }
}
