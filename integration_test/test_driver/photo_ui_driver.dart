import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Screenshots contain only the synthetic fixture and fake identities.
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    if (!RegExp(r'^photo-ui-[a-z-]+$').hasMatch(name)) return false;
    final directory = Directory('/tmp/squadly-photo-ui-device');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes);
    return bytes.isNotEmpty;
  },
  responseDataCallback: (_) async {},
);
