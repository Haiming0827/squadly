import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../domain/push_registration.dart';

/// APNs returns a fresh token on each registration; never cache it in Dart.
final class NativePushTokenSource implements PushTokenSource {
  NativePushTokenSource({MethodChannel? channel, bool? isIOS, bool? isAndroid})
    : _channel = channel ?? const MethodChannel('squadly/notifications'),
      _isIOS = isIOS ?? Platform.isIOS,
      _isAndroid = isAndroid ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _isIOS;
  final bool _isAndroid;

  @override
  String get provider => _isIOS ? 'apns' : 'mipush';

  @override
  Future<bool> isAvailable() async {
    if (!_isIOS && !_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isNotificationsAvailable') ??
          false;
    } on PlatformException catch (error) {
      if (error.code == 'unavailable') return false;
      rethrow;
    }
  }

  @override
  Future<bool> isAuthorized() async {
    if (!_isIOS && !_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('areNotificationsAuthorized') ??
          false;
    } on PlatformException catch (error) {
      if (error.code == 'unavailable') return false;
      rethrow;
    }
  }

  @override
  Future<String?> requestToken() async {
    if (!_isIOS && !_isAndroid) return null;
    try {
      final token = await _channel.invokeMethod<String>(
        _isIOS ? 'requestApnsToken' : 'requestMiPushToken',
      );
      return token?.isNotEmpty == true ? token : null;
    } on PlatformException catch (error) {
      if (error.code == 'permission_denied' || error.code == 'unavailable') {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> unregister() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('unregisterMiPush');
    } on PlatformException catch (error) {
      if (error.code != 'unavailable') rethrow;
    }
  }
}
