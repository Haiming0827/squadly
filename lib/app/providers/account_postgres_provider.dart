import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/cloudbase_auth_gate.dart';
import '../../core/network/cloudbase_client_provider.dart';
import '../../core/network/cloudbase_pg_rest_client.dart';
import '../../core/network/cloudbase_postgres_client.dart';
import 'current_user_provider.dart';

/// Business requests retain their originating account even when an SDK token
/// read completes after sign-out or an account switch. Auth initialization uses
/// the core client because its business identity has not been established yet.
final accountAccessTokenReaderProvider = Provider<AccessTokenReader>((ref) {
  final userId = ref.watch(
    currentUserProvider.select((user) => user.value?.id),
  );
  final app = ref.watch(cloudBaseAppProvider);
  var active = true;
  ref.onDispose(() => active = false);

  return () async {
    if (!active || userId == null || userId.isEmpty) {
      throw const CloudBaseSessionException('业务账号会话不可用');
    }
    final response = await CloudBaseAuthGate.forAuth(app.auth).session();
    final session = response.data?.session;
    final token = session?.accessToken;
    if (!active ||
        !response.isSuccess ||
        session?.user?.id != userId ||
        token == null ||
        token.trim().isEmpty) {
      throw const CloudBaseSessionException('业务账号会话已变化');
    }
    return token;
  };
});

final accountPostgresClientProvider = Provider<CloudBasePostgresClient>((ref) {
  final client = CloudBasePostgresClient(
    config: ref.watch(cloudBaseConfigProvider),
    accessTokenReader: ref.watch(accountAccessTokenReaderProvider),
  );
  ref.onDispose(client.close);
  return client;
});
