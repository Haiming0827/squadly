import 'package:cloudbase_flutter/cloudbase_flutter.dart' hide CloudBaseConfig;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/config/cloudbase_config.dart';
import 'core/network/cloudbase_client_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
        if (cloudBase != null)
          cloudBaseAppProvider.overrideWithValue(cloudBase),
      ],
      child: const SquadlyApp(),
    ),
  );
}
