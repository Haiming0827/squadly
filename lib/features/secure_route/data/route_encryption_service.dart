import 'package:postgrest/postgrest.dart';

import '../domain/route_key_directory.dart';
import '../domain/route_sharing.dart';
import 'route_crypto.dart';
import 'route_device_key_store.dart';

/// Coordinates the explicit per-card approval, protected local key, member
/// device directory and encryption. The caller must supply separately approved
/// teammate public keys (for example, from a fingerprint confirmation UI).
final class RouteEncryptionService implements RouteSharePreparer {
  const RouteEncryptionService({
    required this._keyStore,
    required this._directory,
    required this._crypto,
  });

  final RouteDeviceKeyStore _keyStore;
  final RouteKeyDirectory _directory;
  final RouteCrypto _crypto;

  @override
  Future<EncryptedRouteBundle> prepare({
    required String userId,
    required String squadId,
    required String cardId,
    required int templateVersion,
    required List<RouteCoordinate> route,
    required Map<String, String> approvedPublicKeys,
    required bool explicitlyConfirmed,
  }) async {
    if (!explicitlyConfirmed) {
      throw const RouteShareNotConfirmedException();
    }
    final ownKey = await _keyStore.loadOrCreate(userId: userId);
    await _directory.registerDevice(
      RouteRecipient(
        userId: userId,
        deviceId: ownKey.deviceId,
        publicKeyBase64: ownKey.publicKeyBase64,
      ),
    );
    final recipients = await _directory.listRecipients(squadId);
    if (recipients.isEmpty) {
      throw const UntrustedRouteDeviceException();
    }
    final seen = <String>{};
    var foundOwnDevice = false;
    for (final recipient in recipients) {
      if (!seen.add(recipient.deviceId)) {
        throw const UntrustedRouteDeviceException();
      }
      if (recipient.deviceId == ownKey.deviceId) {
        if (recipient.userId != userId ||
            recipient.publicKeyBase64 != ownKey.publicKeyBase64) {
          throw const UntrustedRouteDeviceException();
        }
        foundOwnDevice = true;
      } else if (approvedPublicKeys[recipient.deviceId] !=
          recipient.publicKeyBase64) {
        throw const UntrustedRouteDeviceException();
      }
    }
    if (!foundOwnDevice) {
      throw const UntrustedRouteDeviceException();
    }
    return _crypto.encryptForMembers(
      squadId: squadId,
      cardId: cardId,
      templateVersion: templateVersion,
      route: route,
      recipients: recipients,
    );
  }
}

/// Uses narrow RPCs instead of direct INSERT on key or membership tables.
typedef RouteSessionUserIdReader = Future<String?> Function();

final class CloudBaseRouteKeyDirectory implements RouteKeyDirectory {
  const CloudBaseRouteKeyDirectory({
    required this._client,
    required this._userIdReader,
  });

  final PostgrestClient _client;
  final RouteSessionUserIdReader _userIdReader;

  @override
  Future<void> registerDevice(RouteRecipient device) async {
    if (await _userIdReader() != device.userId) {
      throw StateError('Route key owner does not match the session');
    }
    final response = await _client.rpc(
      'register_route_device_key',
      params: {
        'p_device_id': device.deviceId,
        'p_public_key': device.publicKeyBase64,
      },
    );
    if (response is! Map ||
        response['user_id'] != device.userId ||
        response['device_id'] != device.deviceId) {
      throw const RouteDeviceRegistrationException();
    }
  }

  @override
  Future<List<RouteRecipient>> listRecipients(String squadId) async {
    final response = await _client.rpc(
      'list_route_recipients',
      params: {'p_squad_id': squadId},
    );
    if (response is! List) {
      throw const FormatException('Malformed route recipient list');
    }
    return response.map((row) {
      if (row is! Map) {
        throw const FormatException('Malformed route recipient');
      }
      final userId = row['user_id'];
      final deviceId = row['device_id'];
      final publicKey = row['public_key'];
      if (userId is! String || deviceId is! String || publicKey is! String) {
        throw const FormatException('Malformed route recipient');
      }
      return RouteRecipient(
        userId: userId,
        deviceId: deviceId,
        publicKeyBase64: publicKey,
      );
    }).toList();
  }
}
