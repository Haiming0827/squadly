import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Captures the local card widget only. No network or cloud storage is used.
final class CardImageRenderer {
  const CardImageRenderer();

  Future<Uint8List> renderPng(GlobalKey repaintBoundaryKey) async {
    final context = repaintBoundaryKey.currentContext;
    if (context == null) {
      throw StateError('Card is not mounted');
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Card must be inside a RepaintBoundary');
    }
    final image = await renderObject.toImage(pixelRatio: 3);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('Could not encode card PNG');
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
