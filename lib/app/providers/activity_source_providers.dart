import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/activity_import/data/apple_health_activity_source.dart';
import '../../features/activity_import/data/gpx_activity_source.dart';
import '../../features/activity_import/data/health_connect_activity_source.dart';
import '../../features/activity_import/domain/activity_source.dart';

final healthActivityAvailableProvider = FutureProvider<bool>((ref) async {
  if (Platform.isIOS) return true;
  if (!Platform.isAndroid) return false;
  try {
    return await const MethodChannel('squadly/health_connect')
            .invokeMethod<bool>('isAvailable') ??
        false;
  } on Exception {
    return false;
  }
});

final healthActivitySourceProvider = Provider<ActivitySource>((ref) {
  if (Platform.isAndroid) return HealthConnectActivitySource();
  return AppleHealthActivitySource();
});

final healthActivitySourceLabelProvider = Provider<String>((ref) {
  return Platform.isAndroid ? 'Health Connect' : 'Apple 健康';
});

final healthActivityLookbackDaysProvider = Provider<int>(
  (ref) => Platform.isAndroid ? 30 : 90,
);

final gpxActivitySourceProvider = Provider<GpxActivitySource>((ref) {
  return GpxActivitySource();
});
