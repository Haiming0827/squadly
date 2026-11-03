import 'dart:async';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' hide CloudBaseConfig;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/cloudbase_config.dart';
import 'cloudbase_auth_gate.dart';
import 'cloudbase_pg_rest_client.dart';
import 'cloudbase_postgres_client.dart';
import 'cloudbase_session_identity.dart';

/// Supplied once by main after the CloudBase SDK restores its persisted session.
final cloudBaseAppProvider = Provider<CloudBase>((ref) {
  throw StateError('CloudBase app is available only in remote mode');
});

final cloudBaseConfigProvider = Provider<CloudBaseConfig>(
  (ref) => CloudBaseConfig.fromEnvironment(),
);

final useDemoBackendProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('USE_DEMO_BACKEND', defaultValue: true),
);

/// One SDK auth instance in production; a separate controlled device session
/// can be injected by native integration tests without touching A/B storage.
final cloudBaseAuthProvider = Provider<CloudBaseAuth>(
  (ref) => ref.watch(cloudBaseAppProvider).auth,
);

final cloudBaseAccessTokenReaderProvider = Provider<AccessTokenReader>((ref) {
  final auth = ref.watch(cloudBaseAuthProvider);
  return () async {
    final sessionResponse = await CloudBaseAuthGate.forAuth(auth).session();
    if (!sessionResponse.isSuccess) {
      if (sessionResponse.error?.code == 'no_session') return null;
      throw CloudBaseSessionException(
        sessionResponse.error?.message ?? 'CloudBase session unavailable',
      );
    }
    final session = sessionResponse.data?.session;
    if (session == null) return null;
    try {
      final identity = cloudBaseSessionIdentity(session);
      if (!DateTime.now().isBefore(identity.expiresAt)) {
        throw const FormatException('Expired SDK session');
      }
    } catch (_) {
      throw const CloudBaseSessionException(
        'CloudBase session is expired or inconsistent',
      );
    }
    return session.accessToken;
  };
});

final cloudBasePgRestClientProvider = Provider<CloudBasePgRestClient>((ref) {
  return CloudBasePgRestClient(
    config: ref.watch(cloudBaseConfigProvider),
    accessTokenReader: ref.watch(cloudBaseAccessTokenReaderProvider),
  );
});

final cloudBasePostgresClientProvider = Provider<CloudBasePostgresClient>((
  ref,
) {
  final client = CloudBasePostgresClient(
    config: ref.watch(cloudBaseConfigProvider),
    accessTokenReader: ref.watch(cloudBaseAccessTokenReaderProvider),
  );
  ref.onDispose(client.close);
  return client;
});

final cloudBaseAuthStateChangesProvider = StreamProvider<CloudBaseAuthEvent>((
  ref,
) {
  final auth = ref.watch(cloudBaseAppProvider).auth;
  late final StreamController<CloudBaseAuthEvent> controller;
  Subscription? subscription;
  controller = StreamController<CloudBaseAuthEvent>.broadcast(
    onListen: () {
      final response = auth.onAuthStateChange((event, session, info) {
        if (controller.isClosed) return;
        controller.add(
          CloudBaseAuthEvent(
            event: event,
            session: session,
            error: info?.error?.message,
          ),
        );
      });
      if (!response.isSuccess) {
        controller.addError(
          CloudBaseSessionException(
            response.error?.message ?? 'CloudBase auth listener failed',
          ),
        );
        return;
      }
      subscription = response.data?.subscription;
    },
    onCancel: () {
      subscription?.unsubscribe();
      subscription = null;
    },
  );
  ref.onDispose(() async {
    await controller.close();
    subscription?.unsubscribe();
  });
  return controller.stream;
});

final class CloudBaseAuthEvent {
  const CloudBaseAuthEvent({required this.event, this.session, this.error});

  final AuthStateChangeEvent event;
  final Session? session;
  final String? error;
}

final class CloudBaseSessionException implements Exception {
  const CloudBaseSessionException(this.message);

  final String message;

  @override
  String toString() => 'CloudBaseSessionException: $message';
}
