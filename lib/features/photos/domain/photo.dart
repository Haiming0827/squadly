import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'photo.freezed.dart';

enum PhotoSource { camera, library }

/// Safe message projection; no object path, image bytes or source metadata.
@freezed
abstract class PhotoAttachment with _$PhotoAttachment {
  const factory PhotoAttachment({
    required String mediaId,
    required int width,
    required int height,
    required int byteLength,
    required bool isRevoked,
  }) = _PhotoAttachment;
}

/// Bytes own their backing storage and cannot change after user confirmation.
final class PhotoImage {
  PhotoImage({
    required Uint8List bytes,
    required this.width,
    required this.height,
    required this.sha256,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    if (bytes.isEmpty ||
        bytes.length > maxBytes ||
        width < 1 ||
        height < 1 ||
        width > maxDimension ||
        height > maxDimension ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw ArgumentError('Invalid prepared photo');
    }
  }

  static const maxBytes = 2 * 1024 * 1024;
  static const maxDimension = 1600;
  final Uint8List bytes;
  final int width;
  final int height;
  final String sha256;
  String get mimeType => 'image/jpeg';

  @override
  String toString() => 'PhotoImage($width x $height, ${bytes.length} bytes)';
}

@freezed
abstract class PhotoTarget with _$PhotoTarget {
  const factory PhotoTarget({
    required String userId,
    required String squadId,
    required String squadName,
    String? replyToMessageId,
  }) = _PhotoTarget;
}

@freezed
abstract class PhotoDraft with _$PhotoDraft {
  const factory PhotoDraft({
    required PhotoTarget target,
    required PhotoImage image,
    required String clientNonce,
    required DateTime preparedAt,
  }) = _PhotoDraft;
}

@freezed
abstract class PublishedPhoto with _$PublishedPhoto {
  const factory PublishedPhoto({
    required String messageId,
    required String mediaId,
    required String squadId,
    required String authorId,
    required String clientNonce,
    required DateTime publishedAt,
    String? replyToMessageId,
  }) = _PublishedPhoto;
}
