import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/photos/domain/photo_repository.dart';
import 'package:squadly/features/photos/domain/prepare_squad_photo.dart';

const _id = '00000000-0000-4000-8000-000000000001';
const _nonce = '00000000-0000-4000-8000-000000000002';
const _target = PhotoTarget(
  userId: 'cloudbase-user',
  squadId: _id,
  squadName: '周末小队',
);

final class _Source implements PhotoSourceGateway {
  int calls = 0;
  Either<Failure, PhotoImage?> result = right(
    PhotoImage(
      bytes: Uint8List.fromList([1, 2, 3]),
      width: 4,
      height: 3,
      sha256: 'a' * 64,
    ),
  );

  @override
  Future<Either<Failure, PhotoImage?>> pick(PhotoSource source) async {
    calls++;
    return result;
  }
}

void main() {
  test('draft retains original target, unique nonce and UTC time without publishing', () async {
    final source = _Source();
    var checks = 0;
    final now = DateTime(2026, 10, 27, 12);
    final prepare = PrepareSquadPhoto(
      source: source,
      canAccess: (target) async {
        checks++;
        expect(target, _target);
        return true;
      },
      nonce: () => _nonce,
      clock: () => now,
    );
    final result = await prepare(target: _target, source: PhotoSource.library);
    final draft = result.getOrElse((_) => null)!;
    expect(draft.target, _target);
    expect(draft.clientNonce, _nonce);
    expect(draft.preparedAt, now.toUtc());
    expect(draft.preparedAt.isUtc, isTrue);
    expect(checks, 2);
    expect(source.calls, 1);
  });

  test(
    'account or membership changes while picking prevent using selected image',
    () async {
      var checks = 0;
      final prepare = PrepareSquadPhoto(
        source: _Source(),
        canAccess: (_) async => ++checks == 1,
        nonce: () => _nonce,
        clock: DateTime.now,
      );
      final result = await prepare(target: _target, source: PhotoSource.camera);
      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<PermissionDeniedFailure>()),
        (_) => fail('Unexpected draft'),
      );
    },
  );

  test('missing initial access does not open the system picker', () async {
    final source = _Source();
    final prepare = PrepareSquadPhoto(
      source: source,
      canAccess: (_) async => false,
      nonce: () => _nonce,
      clock: DateTime.now,
    );
    expect(
      (await prepare(target: _target, source: PhotoSource.camera)).isLeft(),
      isTrue,
    );
    expect(source.calls, 0);
  });

  test('cancel is successful with no draft and no generated nonce', () async {
    final source = _Source()..result = right(null);
    final prepare = PrepareSquadPhoto(
      source: source,
      canAccess: (_) async => true,
      nonce: () => throw StateError('Cancellation cannot enqueue a message'),
      clock: DateTime.now,
    );
    final result = await prepare(target: _target, source: PhotoSource.library);
    expect(result.isRight(), isTrue);
    expect(
      result.getOrElse((_) => throw StateError('Unexpected failure')),
      isNull,
    );
  });

  test(
    'invalid identifiers and blank target fail before accessing a source',
    () async {
      final source = _Source();
      final prepare = PrepareSquadPhoto(
        source: source,
        canAccess: (_) async => throw StateError('Invalid target'),
        nonce: () => _nonce,
        clock: DateTime.now,
      );
      for (final target in [
        _target.copyWith(userId: ''),
        _target.copyWith(userId: 'x' * 65),
        _target.copyWith(squadId: '../other'),
        _target.copyWith(squadName: '  '),
        _target.copyWith(replyToMessageId: 'invalid'),
      ]) {
        final result = await prepare(
          target: target,
          source: PhotoSource.camera,
        );
        result.match(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('Invalid target accepted'),
        );
      }
      expect(source.calls, 0);
    },
  );

  test(
    'source denial and permission lookup failures do not fabricate a draft',
    () async {
      final source = _Source()
        ..result = left(const Failure.permissionDenied(message: 'denied'));
      final prepare = PrepareSquadPhoto(
        source: source,
        canAccess: (_) async => true,
        nonce: () => _nonce,
        clock: DateTime.now,
      );
      expect(
        (await prepare(target: _target, source: PhotoSource.camera)).isLeft(),
        isTrue,
      );
      final unavailable = PrepareSquadPhoto(
        source: source,
        canAccess: (_) async => throw StateError('offline'),
        nonce: () => _nonce,
        clock: DateTime.now,
      );
      expect(
        (await unavailable(
          target: _target,
          source: PhotoSource.camera,
        )).isLeft(),
        isTrue,
      );
    },
  );

  test(
    'photo owns immutable storage and diagnostics omit bytes and digest',
    () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final image = PhotoImage(
        bytes: bytes,
        width: 1,
        height: 1,
        sha256: 'a' * 64,
      );
      bytes[0] = 7;
      expect(image.bytes.first, 1);
      expect(() => image.bytes[0] = 8, throwsUnsupportedError);
      expect(image.toString(), isNot(contains('a' * 64)));
      expect(image.mimeType, 'image/jpeg');
    },
  );

  test(
    'empty, oversized, invalid dimensions and invalid hashes are rejected',
    () {
      for (final length in [0, PhotoImage.maxBytes + 1]) {
        expect(
          () => PhotoImage(
            bytes: Uint8List(length),
            width: 1,
            height: 1,
            sha256: 'a' * 64,
          ),
          throwsArgumentError,
        );
      }
      for (final size in [0, -1, PhotoImage.maxDimension + 1]) {
        expect(
          () => PhotoImage(
            bytes: Uint8List(1),
            width: size,
            height: 1,
            sha256: 'a' * 64,
          ),
          throwsArgumentError,
        );
        expect(
          () => PhotoImage(
            bytes: Uint8List(1),
            width: 1,
            height: size,
            sha256: 'a' * 64,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () =>
            PhotoImage(bytes: Uint8List(1), width: 1, height: 1, sha256: 'bad'),
        throwsArgumentError,
      );
    },
  );
}
