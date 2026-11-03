import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/photos/domain/photo_repository.dart';
import 'package:squadly/features/squad/data/squad_avatar_picker.dart';
import 'package:squadly/features/squad/domain/squad_avatar_format.dart';

final class _Source implements PhotoSourceGateway {
  _Source(this.result);
  final Either<Failure, PhotoImage?> result;
  PhotoSource? requested;
  @override
  Future<Either<Failure, PhotoImage?>> pick(PhotoSource source) async {
    requested = source;
    return result;
  }
}

void main() {
  testWidgets(
    'system source pixels become a decodable 96x96 PNG without JPEG metadata',
    (tester) async {
      final image = PhotoImage(
        bytes: File('test/features/photos/fixtures/sanitized.jpg')
            .readAsBytesSync(),
        width: 4,
        height: 3,
        sha256: 'a' * 64,
      );
      final source = _Source(right(image));
      final result = await tester.runAsync(
        () => PreparedSquadAvatarPicker(source).pick(),
      );
      expect(source.requested, PhotoSource.library);
      expect(result!.isRight(), true);
      final value = result.getRight().toNullable()!;
      final bytes = decodeSquadAvatar(value)!;
      final codec = await tester.runAsync(
        () => ui.instantiateImageCodec(bytes),
      );
      final frame = await tester.runAsync(() => codec!.getNextFrame());
      expect(frame!.image.width, 96);
      expect(frame.image.height, 96);
      expect(bytes.length, lessThanOrEqualTo(squadAvatarMaxBytes));
      frame.image.dispose();
      codec!.dispose();
    },
  );
  test('picker cancellation and source failure are distinct', () async {
    expect(
      (await PreparedSquadAvatarPicker(
        _Source(right(null)),
      ).pick()).getRight().toNullable(),
      isNull,
    );
    expect(
      (await PreparedSquadAvatarPicker(
        _Source(left(const Failure.permissionDenied())),
      ).pick()).getLeft().toNullable(),
      isA<PermissionDeniedFailure>(),
    );
  });
}
