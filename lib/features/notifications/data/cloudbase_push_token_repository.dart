import 'package:postgrest/postgrest.dart';

import '../../../core/network/cloudbase_pg_rest_client.dart';
import '../domain/push_registration.dart';

final class CloudBasePushTokenRepository implements PushTokenRepository {
  const CloudBasePushTokenRepository({
    required this._client,
    required this._accessTokenReader,
  });

  final PostgrestClient _client;
  final AccessTokenReader _accessTokenReader;

  @override
  Future<void> register({
    required String deviceId,
    required String provider,
    required String token,
  }) async {
    if (await _accessTokenReader() == null) throw StateError('Not signed in');
    final response = await _client.rpc(
      'register_push_token',
      params: {
        'p_device_id': deviceId,
        'p_provider': provider,
        'p_token': token,
      },
    );
    if (response is! Map || response['error'] != null) {
      throw StateError('Push token registration failed');
    }
  }

  @override
  Future<void> unregister({
    required String deviceId,
    required String provider,
  }) async {
    if (await _accessTokenReader() == null) return;
    await _client.rpc(
      'unregister_push_token',
      params: {'p_device_id': deviceId, 'p_provider': provider},
    );
  }
}
