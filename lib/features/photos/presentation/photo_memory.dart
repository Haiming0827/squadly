import 'package:flutter/painting.dart';

import '../domain/photo.dart';

/// Drop Flutter's decoded-image cache as well as the view's local reference.
void evictPhotoMemory(PhotoImage? image) {
  if (image == null) return;
  PaintingBinding.instance.imageCache.evict(
    MemoryImage(image.bytes),
    includeLive: true,
  );
}
