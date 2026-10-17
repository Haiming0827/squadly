import 'dart:async';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' hide CloudBaseConfig;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/cloudbase_config.dart';
import 'cloudbase_pg_rest_client.dart';
import 'cloudbase_postgres_client.dart';

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

final cloudBaseAccessTokenReaderProvider = Provider<AccessTokenReader>((ref) {
  final app = ref.watch(cloudBaseAppProvider);
  return () async {
    final sessionResponse = await app.auth.getSession();
    if (!sessionResponse.isSuccess) {
      if (sessionResponse.error?.code == 'no_session') return null;
      throw CloudBaseSessionException(
        sessionResponse.error?.message ?? 'CloudBase session unavailable',
      );
    }
    return sessionResponse.data?.session?.accessToken;
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
