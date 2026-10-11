import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/route_crypto.dart';
import '../data/route_decryption_service.dart';
import '../data/route_device_key_store.dart';
import '../data/route_encryption_service.dart';
import '../data/supabase_route_bundle_repository.dart';
import '../domain/route_reader.dart';

final routeCryptoProvider = Provider<RouteCrypto>((ref) => RouteCrypto());

final routeDeviceKeyStoreProvider = Provider<RouteDeviceKeyStore>((ref) {
  return RouteDeviceKeyStore(
    vault: FlutterRouteSecretVault(),
    crypto: ref.watch(routeCryptoProvider),
  );
});

final routeKeyDirectoryProvider = Provider<RouteKeyDirectory>((ref) {
  return SupabaseRouteKeyDirectory(ref.watch(supabaseClientProvider));
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
    repository: SupabaseRouteBundleRepository(
      ref.watch(supabaseClientProvider),
    ),
    crypto: ref.watch(routeCryptoProvider),
  );
});
