import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/push_registration.dart';

final class SupabasePushTokenRepository implements PushTokenRepository {
  const SupabasePushTokenRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> register({
    required String deviceId,
    required String provider,
    required String token,
  }) async {
    if (_client.auth.currentUser == null) throw StateError('Not signed in');
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
    if (_client.auth.currentUser == null) return;
    await _client.rpc(
      'unregister_push_token',
      params: {'p_device_id': deviceId, 'p_provider': provider},
    );
  }
}
