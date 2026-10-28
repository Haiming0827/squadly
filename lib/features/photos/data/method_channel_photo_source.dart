import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly_photo_bridge/squadly_photo_bridge.dart';

import '../../../core/error/failures.dart';
import '../domain/photo.dart';
import '../domain/photo_repository.dart';
import '../domain/prepared_photo_format.dart';

final class MethodChannelPhotoSource implements PhotoSourceGateway {
  const MethodChannelPhotoSource({
    this._channel = const MethodChannel(photoBridgeChannel),
  });

  final MethodChannel _channel;

  @override
  Future<Either<Failure, PhotoImage?>> pick(PhotoSource source) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'pickPhoto',
        {'source': source.name},
      );
      if (result == null) return right(null);
      if (result.length != 3 ||
          !result.keys.toSet().containsAll({'bytes', 'width', 'height'})) {
        throw const FormatException('Unexpected native photo fields');
      }
      final bytes = result['bytes'];
      final width = result['width'];
      final height = result['height'];
      if (bytes is! Uint8List ||
          width is! int ||
          height is! int ||
          bytes.length > PhotoImage.maxBytes ||
          !isPreparedJpeg(bytes, width, height)) {
        throw const FormatException('Invalid prepared JPEG');
      }
      final hash = await Sha256().hash(bytes);
      return right(
        PhotoImage(
          bytes: bytes,
          width: width,
          height: height,
          sha256: hash.bytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(),
        ),
      );
    } on PlatformException catch (error) {
      return left(switch (error.code) {
        'permission_denied' => const Failure.permissionDenied(
          message: '相机权限未开启，可改用相册选图',
        ),
        'busy' => const Failure.validation(message: '请先完成当前照片选择'),
        'invalid_image' ||
        'image_too_large' => const Failure.validation(message: '这张照片无法使用，请换一张'),
        _ => const Failure.server(message: '当前设备暂时无法使用此照片来源'),
      });
    } on MissingPluginException {
      return left(const Failure.server(message: '当前版本暂不支持此照片来源'));
    } catch (_) {
      return left(const Failure.validation(message: '照片准备失败，请重新选择'));
    }
  }
}
