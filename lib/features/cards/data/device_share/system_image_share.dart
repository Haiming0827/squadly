import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/device_image_share.dart';

final class SystemImageShare implements DeviceImageShare {
  const SystemImageShare();

  @override
  Future<void> saveImage(Uint8List pngBytes) async {
    if (pngBytes.isEmpty) throw ArgumentError.value(pngBytes, 'pngBytes');
    await Gal.putImageBytes(pngBytes, name: 'squadly-card');
  }

  @override
  Future<ShareOutcome> shareImage(Uint8List pngBytes) async {
    if (pngBytes.isEmpty) throw ArgumentError.value(pngBytes, 'pngBytes');
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            pngBytes,
            mimeType: 'image/png',
            name: 'squadly-card.png',
          ),
        ],
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => ShareOutcome.selectedTarget,
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable => ShareOutcome.unavailable,
    };
  }
}
