import 'package:postgrest/postgrest.dart';

import '../domain/route_bundle_repository.dart';
import '../domain/route_models.dart';

typedef RouteUserIdReader = Future<String?> Function();

/// Reads route ciphertext and the signed-in device's envelope only.
final class CloudBaseRouteBundleRepository implements RouteBundleRepository {
  const CloudBaseRouteBundleRepository({
    required PostgrestClient client,
    required RouteUserIdReader userIdReader,
  }) : _client = client,
       _userIdReader = userIdReader;

  final PostgrestClient _client;
  final RouteUserIdReader _userIdReader;

  @override
  Future<EncryptedRouteBundle> loadForDevice({
    required String squadId,
    required String cardId,
    required String userId,
    required String deviceId,
  }) async {
    if (await _userIdReader() != userId) {
      throw const RouteEnvelopeUnavailable();
    }
    final cipher = await _client
        .from('card_route_ciphertexts')
        .select('algorithm,nonce,ciphertext,mac')
        .eq('card_id', cardId)
        .eq('squad_id', squadId)
        .maybeSingle();
    if (cipher == null) throw const RouteBundleUnavailable();

    final envelope = await _client
        .from('card_route_envelopes')
        .select(
          'recipient_user_id,recipient_device_id,ephemeral_public_key,salt,nonce,ciphertext,mac',
        )
        .eq('card_id', cardId)
        .eq('squad_id', squadId)
        .eq('recipient_user_id', userId)
        .eq('recipient_device_id', deviceId)
        .maybeSingle();
    if (envelope == null) throw const RouteEnvelopeUnavailable();
    if (cipher['algorithm'] != EncryptedRouteBundle.algorithm) {
      throw const FormatException('Unsupported route algorithm');
    }
    return EncryptedRouteBundle(
      route: RouteCiphertext(
        nonce: cipher['nonce'] as String,
        ciphertext: cipher['ciphertext'] as String,
        mac: cipher['mac'] as String,
      ),
      envelopes: [RouteKeyEnvelope.fromJson(envelope)],
    );
  }
}
