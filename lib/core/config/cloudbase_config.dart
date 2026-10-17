/// Public CloudBase client configuration. Never store server API keys here.
final class CloudBaseConfig {
  const CloudBaseConfig._({
    required this.useDemo,
    required this.environmentId,
    required this.region,
    required this.publishableKey,
  });

  final bool useDemo;
  final String environmentId;
  final String region;
  final String publishableKey;

  String get apiBaseUrl {
    final gateway = region == 'ap-singapore'
        ? 'api.intl.tcloudbasegateway.com'
        : 'api.tcloudbasegateway.com';
    return 'https://$environmentId.$gateway';
  }

  String get postgresRestBaseUrl => '$apiBaseUrl/v1/rdb/rest';

  factory CloudBaseConfig.fromValues({
    required String useDemo,
    required String environmentId,
    required String region,
    required String publishableKey,
  }) {
    if (useDemo != 'true' && useDemo != 'false') {
      throw const FormatException('USE_DEMO_BACKEND must be true or false');
    }
    final demo = useDemo == 'true';
    if (!demo &&
        (environmentId.trim().isEmpty ||
            !_isValidEnvironmentId(environmentId) ||
            environmentId.contains('your-') ||
            environmentId.contains('replace-with') ||
            !const {'ap-shanghai', 'ap-singapore'}.contains(region) ||
            publishableKey.trim().length < 20 ||
            publishableKey.contains('your-') ||
            publishableKey.contains('replace-with') ||
            _looksLikeServerKey(publishableKey))) {
      throw const FormatException(
        'Real backend requires a CloudBase environment ID, supported region, and public Publishable Key',
      );
    }
    return CloudBaseConfig._(
      useDemo: demo,
      environmentId: environmentId.trim(),
      region: region,
      publishableKey: publishableKey.trim(),
    );
  }

  factory CloudBaseConfig.fromEnvironment() => CloudBaseConfig.fromValues(
    useDemo: const String.fromEnvironment(
      'USE_DEMO_BACKEND',
      defaultValue: 'true',
    ),
    environmentId: const String.fromEnvironment(
      'CLOUDBASE_ENV_ID',
      defaultValue: 'your-cloudbase-environment',
    ),
    region: const String.fromEnvironment(
      'CLOUDBASE_REGION',
      defaultValue: 'ap-shanghai',
    ),
    publishableKey: const String.fromEnvironment(
      'CLOUDBASE_PUBLISHABLE_KEY',
      defaultValue: 'your-cloudbase-publishable-key',
    ),
  );

  static bool _looksLikeServerKey(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('secretkey') ||
        normalized.contains('secret_key') ||
        normalized.contains('service_role') ||
        normalized.contains('service-role');
  }

  static bool _isValidEnvironmentId(String value) =>
      RegExp(r'^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*$').hasMatch(value.trim());
}
