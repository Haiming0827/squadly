import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/cloudbase_client_provider.dart';
import '../data/cloudbase_route_bundle_repository.dart';
import '../data/route_crypto.dart';
import '../data/route_decryption_service.dart';
import '../data/route_device_key_store.dart';
import '../data/route_encryption_service.dart';
import '../domain/route_reader.dart';

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
    client: ref.watch(cloudBasePostgresClientProvider).rest,
    userIdReader: () async {
      final response = await app.auth.getSession();
      if (!response.isSuccess) return null;
      return response.data?.session?.user?.id;
    },
  );
});

final routeEncryptionServiceProvider = Provider<RouteEncryptionService>((ref) {
  return RouteEncryptionService(
    keyStore: ref.watch(routeDeviceKeyStoreProvider),
    directory: ref.watch(routeKeyDirectoryProvider),
    crypto: ref.watch(routeCryptoProvider),
  );
});

final routeReaderProvider = Provider<RouteReader>((ref) {
  return RouteDecryptionService(
    keyStore: ref.watch(routeDeviceKeyStoreProvider),
    repository: CloudBaseRouteBundleRepository(
      client: ref.watch(cloudBasePostgresClientProvider).rest,
      userIdReader: () async {
        final response = await ref.read(cloudBaseAppProvider).auth.getSession();
        if (!response.isSuccess) return null;
        return response.data?.session?.user?.id;
      },
    ),
    crypto: ref.watch(routeCryptoProvider),
  );
});
