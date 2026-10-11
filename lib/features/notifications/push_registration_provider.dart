import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_client_provider.dart';
import 'data/native_push_token_source.dart';
import 'data/secure_push_device_id_store.dart';
import 'data/supabase_push_token_repository.dart';
import 'domain/push_registration.dart';

final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  return PushRegistration(
    source: NativePushTokenSource(),
    deviceIds: SecurePushDeviceIdStore(),
    repository: SupabasePushTokenRepository(ref.watch(supabaseClientProvider)),
  );
});
