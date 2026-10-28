import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/cloudbase_client_provider.dart';
import '../../features/secure_route/data/cloudbase_route_bundle_repository.dart';
import '../../features/secure_route/data/route_crypto.dart';
import '../../features/secure_route/data/route_decryption_service.dart';
import '../../features/secure_route/data/route_device_key_store.dart';
import '../../features/secure_route/data/route_encryption_service.dart';
import '../../features/secure_route/domain/route_key_directory.dart';
import '../../features/secure_route/domain/route_reader.dart';
import '../../features/secure_route/domain/route_sharing.dart';
import 'account_postgres_provider.dart';

/// Application composition for secure route domain contracts.
final routeCryptoProvider = Provider<RouteCrypto>((ref) => RouteCrypto());

final routeDeviceKeyStoreProvider = Provider<RouteDeviceKeyStore>((ref) {
  return RouteDeviceKeyStore(
    vault: FlutterRouteSecretVault(),
    crypto: ref.watch(routeCryptoProvider),
  );
});

final routeKeyDirectoryProvider = Provider<RouteKeyDirectory>((ref) {
  final app = ref.watch(cloudBaseAppProvider);
  return CloudBaseRouteKeyDirectory(
    client: ref.watch(accountPostgresClientProvider).rest,
    userIdReader: () async {
      final response = await app.auth.getSession();
      if (!response.isSuccess) return null;
      return response.data?.session?.user?.id;
    },
  );
});

final routeSharePreparerProvider = Provider<RouteSharePreparer>((ref) {
  return RouteEncryptionService(
    keyStore: ref.watch(routeDeviceKeyStoreProvider),
    directory: ref.watch(routeKeyDirectoryProvider),
    crypto: ref.watch(routeCryptoProvider),
  );
});

/// Backwards-compatible feature name; new cross-feature clients should depend
/// on the domain-facing [routeSharePreparerProvider].
final routeEncryptionServiceProvider = routeSharePreparerProvider;

final routeReaderProvider = Provider<RouteReader>((ref) {
  return RouteDecryptionService(
    keyStore: ref.watch(routeDeviceKeyStoreProvider),
    repository: CloudBaseRouteBundleRepository(
      client: ref.watch(accountPostgresClientProvider).rest,
      userIdReader: () async {
        final response = await ref.read(cloudBaseAppProvider).auth.getSession();
        if (!response.isSuccess) return null;
        return response.data?.session?.user?.id;
      },
    ),
    crypto: ref.watch(routeCryptoProvider),
  );
});
