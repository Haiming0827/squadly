import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/config/backend_config.dart';

void main() {
  test('demo mode permits local placeholder configuration', () {
    final config = BackendConfig.fromValues(
      useDemo: 'true',
      url: 'https://your-project.supabase.co',
      anonKey: 'your-anon-key',
    );
    expect(config.useDemo, isTrue);
  });

  test('real mode rejects missing and placeholder backend values', () {
    expect(
      () => BackendConfig.fromValues(
        useDemo: 'false',
        url: 'https://your-project.supabase.co',
        anonKey: 'your-anon-key',
      ),
      throwsFormatException,
    );
    expect(
      () => BackendConfig.fromValues(
        useDemo: 'false',
        url: 'http://example.com',
        anonKey: 'a-valid-looking-public-key',
      ),
      throwsFormatException,
    );
  });

  test('real mode accepts public staging client configuration', () {
    final config = BackendConfig.fromValues(
      useDemo: 'false',
      url: 'https://staging.example.com',
      anonKey: 'a-valid-looking-public-key',
    );
    expect(config.useDemo, isFalse);
  });

  test('real mode only accepts cleartext URLs for explicit loopback tests', () {
    final config = BackendConfig.fromValues(
      useDemo: 'false',
      url: 'http://127.0.0.1:54321',
      anonKey: 'a-valid-looking-public-key',
      allowLocalHttp: true,
    );
    expect(config.useDemo, isFalse);

    expect(
      () => BackendConfig.fromValues(
        useDemo: 'false',
        url: 'http://192.168.1.20:54321',
        anonKey: 'a-valid-looking-public-key',
        allowLocalHttp: true,
      ),
      throwsFormatException,
    );
  });
}
