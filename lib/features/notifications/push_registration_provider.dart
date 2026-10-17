import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/cloudbase_client_provider.dart';
import 'data/cloudbase_push_token_repository.dart';
import 'data/native_push_token_source.dart';
import 'data/secure_push_device_id_store.dart';
import 'domain/push_registration.dart';

final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  return PushRegistration(
    source: NativePushTokenSource(),
    deviceIds: SecurePushDeviceIdStore(),
    repository: CloudBasePushTokenRepository(
      client: ref.watch(cloudBasePostgresClientProvider).rest,
      accessTokenReader: ref.watch(cloudBaseAccessTokenReaderProvider),
    ),
  );
});
