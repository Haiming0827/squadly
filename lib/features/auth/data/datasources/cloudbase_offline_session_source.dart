import 'dart:async';
import 'dart:convert';

import 'package:cloudbase_flutter/cloudbase_flutter.dart';

import '../../domain/offline_session.dart';

/// Reads the SDK's restored session event; never calls getSession/getUser,
/// refreshToken, HTTP, or SDK private storage. InitialSession works offline.
final class CloudBaseOfflineSessionSource implements OfflineSessionSource {
  CloudBaseOfflineSessionSource(this._auth);
  final CloudBaseAuth _auth;

  @override
  Stream<OfflineSession?> watch() {
    late final StreamController<OfflineSession?> controller;
    Subscription? subscription;
    controller = StreamController<OfflineSession?>(
      onListen: () {
        try {
          final result = _auth.onAuthStateChange((event, session, info) {
            if (controller.isClosed) return;
            try {
              controller.add(
                session == null ? null : offlineSessionFromSdk(session),
              );
            } catch (_) {
              controller.addError(
                const FormatException('Local session unavailable'),
              );
            }
          });
          if (!result.isSuccess) {
            controller.addError(StateError('Local session unavailable'));
          }
          subscription = result.data?.subscription;
        } catch (_) {
          controller.addError(StateError('Local session unavailable'));
        }
      },
      onCancel: () => subscription?.unsubscribe(),
    );
    return controller.stream;
  }
}

/// The token was already accepted/persisted by the SDK's online auth flow.
/// Decoding here is solely a conservative local-expiry/identity check, not JWT
/// signature verification or a substitute for server authorization.
OfflineSession offlineSessionFromSdk(Session session) {
  final token = session.accessToken;
  final userId = session.user?.id;
  if (token == null ||
      token.isEmpty ||
      token.length > 32768 ||
      userId == null ||
      userId.isEmpty) {
    throw const FormatException('Local session unavailable');
  }
  final parts = token.split('.');
  if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
    throw const FormatException('Local session unavailable');
  }
  final claims = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
  );
  if (claims is! Map ||
      claims['sub'] != userId ||
      claims['exp'] is! int ||
      claims['exp'] <= 0) {
    throw const FormatException('Local session unavailable');
  }
  var expiry = DateTime.fromMillisecondsSinceEpoch(
    (claims['exp'] as int) * 1000,
    isUtc: true,
  );
  final sdkExpiry = session.expiresAt;
  if (sdkExpiry != null) {
    if (sdkExpiry <= 0) {
      throw const FormatException('Local session unavailable');
    }
    // SDK releases may retain API epoch seconds or computed epoch milliseconds.
    final candidate = DateTime.fromMillisecondsSinceEpoch(
      sdkExpiry < 100000000000 ? sdkExpiry * 1000 : sdkExpiry,
      isUtc: true,
    );
    if (candidate.isBefore(expiry)) expiry = candidate;
  }
  return OfflineSession(userId: userId, expiresAt: expiry);
}
