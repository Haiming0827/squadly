import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/photos/domain/coordinated_photo_safety.dart';
import 'package:squadly/features/photos/domain/photo_safety_repository.dart';

class Safety implements PhotoSafetyRepository {
  final calls = <String>[];
  Future<Either<Failure, void>> Function()? action;
  Future<Either<Failure, void>> run(String name) async {
    calls.add(name);
    return action == null ? right(null) : action!();
  }

  @override
  Future<Either<Failure, void>> hide({
    required String squadId,
    required String messageId,
  }) => run('$squadId/$messageId');
  @override
  Future<Either<Failure, void>> report({
    required String squadId,
    required String messageId,
    required PhotoReportReason reason,
  }) => run('$squadId/$messageId/${reason.name}');
}

void main() {
  test('local pixels are protected before remote commit and refresh follows confirmation', () async {
    final repository = Safety();
    final order = <String>[];
    repository.action = () async {
      order.add('commit');
      return right(null);
    };
    final coordinator = CoordinatedPhotoSafety(
      repository: repository,
      isCurrent: () => true,
      protect: (squad, message) async {
        expect((squad, message), ('squad', 'message'));
        order.add('clear');
      },
      confirmed: () async => order.add('refresh'),
    );
    expect(
      (await coordinator.report(
        squadId: 'squad',
        messageId: 'message',
        reason: PhotoReportReason.privacy,
      )).isRight(),
      isTrue,
    );
    expect(order, ['clear', 'commit', 'refresh']);
    expect(repository.calls, ['squad/message/privacy']);
  });
  test(
    'account change while protecting prevents any remote mutation',
    () async {
      final repository = Safety();
      var current = true;
      final coordinator = CoordinatedPhotoSafety(
        repository: repository,
        isCurrent: () => current,
        protect: (_, _) async => current = false,
        confirmed: () async => fail('No refresh'),
      );
      expect(
        (await coordinator.hide(squadId: 's', messageId: 'm')).isLeft(),
        isTrue,
      );
      expect(repository.calls, isEmpty);
    },
  );
  test('late remote confirmation after account switch is rejected', () async {
    final repository = Safety();
    final result = Completer<Either<Failure, void>>();
    repository.action = () => result.future;
    var current = true;
    final coordinator = CoordinatedPhotoSafety(
      repository: repository,
      isCurrent: () => current,
      protect: (_, _) async {},
      confirmed: () async => fail('No refresh'),
    );
    final pending = coordinator.hide(squadId: 's', messageId: 'm');
    await Future<void>.delayed(Duration.zero);
    current = false;
    result.complete(right(null));
    expect((await pending).isLeft(), isTrue);
  });
  test('remote denial does not refresh or claim confirmation', () async {
    final repository = Safety()
      ..action = () async => left(const Failure.permissionDenied());
    final coordinator = CoordinatedPhotoSafety(
      repository: repository,
      isCurrent: () => true,
      protect: (_, _) async {},
      confirmed: () async => fail('No refresh'),
    );
    expect(
      (await coordinator.hide(squadId: 's', messageId: 'm')).isLeft(),
      isTrue,
    );
  });
}
