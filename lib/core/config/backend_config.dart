/// Checks the public client configuration before any real-backend UI starts.
/// Server-side secrets must never be passed through this object.
final class BackendConfig {
  BackendConfig._({
    required this.useDemo,
    required this.url,
    required this.anonKey,
  });

  final bool useDemo;
  final String url;
  final String anonKey;

  factory BackendConfig.fromValues({
    required String useDemo,
    required String url,
    required String anonKey,
    bool allowLocalHttp = false,
  }) {
    if (useDemo != 'true' && useDemo != 'false') {
      throw const FormatException('USE_DEMO_BACKEND must be true or false');
    }
    final demo = useDemo == 'true';
    if (!demo) {
      final parsed = Uri.tryParse(url);
      final isSecureHttps = parsed?.scheme == 'https';
      final isExplicitLoopbackTest =
          allowLocalHttp &&
          parsed?.scheme == 'http' &&
          const {'localhost', '127.0.0.1', '::1'}.contains(parsed?.host);
      if (parsed == null ||
          (!isSecureHttps && !isExplicitLoopbackTest) ||
          parsed.host.isEmpty ||
          parsed.userInfo.isNotEmpty ||
          parsed.host.contains('your-project') ||
          parsed.host.contains('replace-with') ||
          anonKey.length < 20 ||
          anonKey.contains('your-anon-key') ||
          anonKey.contains('replace-with')) {
        throw const FormatException(
          'Real backend requires a staging URL and publishable key',
        );
      }
    }
    return BackendConfig._(useDemo: demo, url: url, anonKey: anonKey);
  }

  factory BackendConfig.fromEnvironment() => BackendConfig.fromValues(
    useDemo: const String.fromEnvironment(
      'USE_DEMO_BACKEND',
      defaultValue: 'true',
    ),
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://your-project.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'your-anon-key',
    ),
    allowLocalHttp: const bool.fromEnvironment(
      'ENABLE_LOCAL_HTTP_BACKEND',
      defaultValue: false,
    ),
  );
}
