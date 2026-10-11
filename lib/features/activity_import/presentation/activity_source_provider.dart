import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/apple_health_activity_source.dart';
import '../data/gpx_activity_source.dart';
import '../domain/activity_source.dart';

final appleHealthAvailableProvider = Provider<bool>((ref) => Platform.isIOS);

final appleHealthActivitySourceProvider = Provider<ActivitySource>((ref) {
  return AppleHealthActivitySource();
});

final gpxActivitySourceProvider = Provider<GpxActivitySource>((ref) {
  return GpxActivitySource();
});
