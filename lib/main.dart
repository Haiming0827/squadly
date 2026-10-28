import 'dart:async';
import 'dart:ui';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' hide CloudBaseConfig;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers/diagnostics_provider.dart';
import 'app/providers/offline_access_provider.dart';
import 'core/config/cloudbase_config.dart';
import 'core/network/cloudbase_client_provider.dart';
import 'features/auth/data/datasources/cloudbase_offline_session_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostics = DiagnosticSettingsController.configured();
  await diagnostics.restore();
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(
      diagnostics.capture(details.exception, details.stack ?? StackTrace.empty),
    );
    previousFlutterError?.call(details);
  };
  final previousPlatformError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(diagnostics.capture(error, stack));
    return previousPlatformError?.call(error, stack) ?? false;
  };

  final config = CloudBaseConfig.fromEnvironment();
  final cloudBase = config.useDemo
      ? null
      : await CloudBase.init(
          env: config.environmentId,
          region: config.region,
          accessKey: config.publishableKey,
        );

  runApp(
    ProviderScope(
      overrides: [
        diagnosticsProvider.overrideWith((ref) => diagnostics),
        if (cloudBase != null)
          cloudBaseAppProvider.overrideWithValue(cloudBase),
        if (cloudBase != null)
          offlineSessionSourceProvider.overrideWithValue(
            CloudBaseOfflineSessionSource(cloudBase.auth),
          ),
      ],
      child: const SquadlyApp(),
    ),
  );
}
