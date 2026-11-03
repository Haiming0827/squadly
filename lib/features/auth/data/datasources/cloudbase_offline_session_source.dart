import 'dart:async';

import 'package:cloudbase_flutter/cloudbase_flutter.dart';

import '../../../../core/network/cloudbase_session_identity.dart';
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
  final identity = cloudBaseSessionIdentity(session);
  return OfflineSession(userId: identity.userId, expiresAt: identity.expiresAt);
}
