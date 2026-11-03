import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fpdart/fpdart.dart';

import '../../../core/error/failures.dart';
import '../../photos/domain/photo.dart';
import '../../photos/domain/photo_repository.dart';
import '../domain/repositories/squad_profile_repository.dart';
import '../domain/squad_avatar_format.dart';

final class PreparedSquadAvatarPicker implements SquadAvatarPicker {
  const PreparedSquadAvatarPicker(this.source);
  final PhotoSourceGateway source;
  @override
  Future<Either<Failure, String?>> pick() async {
    final result = await source.pick(PhotoSource.library);
    return result.match((failure) async => left(failure), (photo) async {
      if (photo == null) return right(null);
      ui.Codec? codec;
      ui.Image? image;
      ui.Image? thumbnail;
      ui.Picture? picture;
      try {
        codec = await ui.instantiateImageCodec(photo.bytes);
        image = (await codec.getNextFrame()).image;
        final size = image.width < image.height
            ? image.width.toDouble()
            : image.height.toDouble();
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(
            (image.width - size) / 2,
            (image.height - size) / 2,
            size,
            size,
          ),
          const ui.Rect.fromLTWH(0, 0, 96, 96),
          ui.Paint()..filterQuality = ui.FilterQuality.high,
        );
        picture = recorder.endRecording();
        thumbnail = await picture.toImage(96, 96);
        final data = await thumbnail.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw const FormatException();
        final avatar =
            '$squadAvatarPrefix${base64Encode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes))}';
        if (decodeSquadAvatar(avatar) == null) throw const FormatException();
        return right(avatar);
      } catch (_) {
        return left(const Failure.validation(message: '头像准备失败，请重新选择'));
      } finally {
        thumbnail?.dispose();
        picture?.dispose();
        image?.dispose();
        codec?.dispose();
      }
    });
  }
}
