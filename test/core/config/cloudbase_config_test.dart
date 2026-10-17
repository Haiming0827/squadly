import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/config/cloudbase_config.dart';

void main() {
  test(
    'demo mode accepts placeholders without requiring a CloudBase project',
    () {
      final config = CloudBaseConfig.fromValues(
        useDemo: 'true',
        environmentId: 'your-cloudbase-environment',
        region: 'ap-shanghai',
        publishableKey: 'your-cloudbase-publishable-key',
      );

      expect(config.useDemo, isTrue);
    },
  );

  test('real mode accepts public CloudBase configuration', () {
    final config = CloudBaseConfig.fromValues(
      useDemo: 'false',
      environmentId: 'squadly-prod-123456',
      region: 'ap-shanghai',
      publishableKey: 'a-valid-public-publishable-key',
    );

    expect(
      config.postgresRestBaseUrl,
      'https://squadly-prod-123456.api.tcloudbasegateway.com/v1/rdb/rest',
    );
  });

  test('real mode rejects placeholders, invalid regions, and server keys', () {
    for (final values in [
      ('your-cloudbase-env', 'ap-shanghai', 'a-valid-public-publishable-key'),
      ('bad/env-id', 'ap-shanghai', 'a-valid-public-publishable-key'),
      ('squadly-prod-123456', 'ap-beijing', 'a-valid-public-publishable-key'),
      ('squadly-prod-123456', 'ap-guangzhou', 'a-valid-public-publishable-key'),
      ('squadly-prod-123456', 'ap-shanghai', 'service_role_secret_key_12345'),
    ]) {
      expect(
        () => CloudBaseConfig.fromValues(
          useDemo: 'false',
          environmentId: values.$1,
          region: values.$2,
          publishableKey: values.$3,
        ),
        throwsFormatException,
      );
    }
  });

  test('uses the international gateway for Singapore', () {
    final config = CloudBaseConfig.fromValues(
      useDemo: 'false',
      environmentId: 'squadly-prod-123456',
      region: 'ap-singapore',
      publishableKey: 'a-valid-public-publishable-key',
    );

    expect(
      config.apiBaseUrl,
      'https://squadly-prod-123456.api.intl.tcloudbasegateway.com',
    );
  });

  test('rejects invalid demo mode', () {
    expect(
      () => CloudBaseConfig.fromValues(
        useDemo: 'yes',
        environmentId: '',
        region: 'ap-shanghai',
        publishableKey: '',
      ),
      throwsFormatException,
    );
  });
}
