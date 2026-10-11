import '../domain/route_bundle_repository.dart';
import '../domain/route_reader.dart';
import 'route_crypto.dart';
import 'route_device_key_store.dart';

/// Decrypts only into ephemeral app memory; never writes route samples to the
/// cloud, analytics or an unprotected disk cache.
final class RouteDecryptionService implements RouteReader {
  const RouteDecryptionService({
    required RouteDeviceKeyStore keyStore,
    required RouteBundleRepository repository,
    required RouteCrypto crypto,
  }) : _keyStore = keyStore,
       _repository = repository,
       _crypto = crypto;

  final RouteDeviceKeyStore _keyStore;
  final RouteBundleRepository _repository;
  final RouteCrypto _crypto;

  @override
  Future<List<RouteCoordinate>> loadForMe({
    required String squadId,
    required String cardId,
    required int templateVersion,
    required String userId,
  }) async {
    final key = await _keyStore.loadExisting(userId: userId);
    if (key == null) throw const RouteKeyMissing();
    final bundle = await _repository.loadForDevice(
      squadId: squadId,
      cardId: cardId,
      userId: userId,
      deviceId: key.deviceId,
    );
    return _crypto.decryptForMe(
      bundle: bundle,
      squadId: squadId,
      cardId: cardId,
      templateVersion: templateVersion,
      userId: userId,
      key: key,
    );
  }
}
