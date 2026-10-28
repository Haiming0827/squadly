import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/photos/data/method_channel_photo_source.dart';
import 'package:squadly/features/photos/domain/photo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('squadly/photos');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final fixture = File('test/features/photos/fixtures/sanitized.jpg')
      .readAsBytesSync();

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'prepares only decoded JPEG bytes and no original path or metadata',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'pickPhoto');
        expect(call.arguments, {'source': 'library'});
        return {'bytes': fixture, 'width': 4, 'height': 3};
      });
      final result = await const MethodChannelPhotoSource().pick(
        PhotoSource.library,
      );
      final image = result.getOrElse((_) => null)!;
      expect(image.width, 4);
      expect(image.height, 3);
      expect(image.bytes, fixture);
      expect(
        image.sha256,
        '9c4ad0cc80a44a2d234c284e474e8feff187fb71a568f3b09d6c5737e49e0cd5',
      );
    },
  );

  test('native cancellation has no prepared photo', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final result = await const MethodChannelPhotoSource().pick(
      PhotoSource.camera,
    );
    expect(result.isRight(), isTrue);
    expect(
      result.getOrElse((_) => throw StateError('Unexpected error')),
      isNull,
    );
  });

  test(
    'permission denial and busy map to actionable Chinese failures',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'permission_denied'),
      );
      final denied = await const MethodChannelPhotoSource().pick(
        PhotoSource.camera,
      );
      denied.match(
        (failure) => expect(failure, isA<PermissionDeniedFailure>()),
        (_) => fail('Permission accepted'),
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'busy'),
      );
      final busy = await const MethodChannelPhotoSource().pick(
        PhotoSource.library,
      );
      busy.match(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Concurrent picker accepted'),
      );
    },
  );

  test(
    'rejects EXIF/IPTC/comment data, mismatched size and invalid JPEG',
    () async {
      final cases = <Map<String, Object>>[
        {'bytes': fixture, 'width': 5, 'height': 3},
        {
          'bytes': fixture,
          'width': 4,
          'height': 3,
          'originalPath': '/private/library.jpg',
        },
        {
          'bytes': Uint8List.fromList([1, 2, 3]),
          'width': 4,
          'height': 3,
        },
        {
          'bytes': Uint8List.fromList([...fixture, 1]),
          'width': 4,
          'height': 3,
        },
        for (final marker in [0xe1, 0xed, 0xfe])
          {
            'bytes': Uint8List.fromList([
              0xff,
              0xd8,
              0xff,
              marker,
              0,
              4,
              0,
              0,
              ...fixture.skip(2),
            ]),
            'width': 4,
            'height': 3,
          },
      ];
      for (final value in cases) {
        messenger.setMockMethodCallHandler(channel, (_) async => value);
        final result = await const MethodChannelPhotoSource().pick(
          PhotoSource.library,
        );
        expect(
          result.isLeft(),
          isTrue,
          reason: 'Invalid native output was accepted',
        );
      }
    },
  );

  test(
    'unsupported platform does not fabricate a successful selection',
    () async {
      final result = await const MethodChannelPhotoSource().pick(
        PhotoSource.camera,
      );
      expect(result.isLeft(), isTrue);
    },
  );
}
