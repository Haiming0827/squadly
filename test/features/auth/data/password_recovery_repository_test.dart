import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:squadly/features/auth/data/repositories/auth_repository_impl.dart';

class _Remote extends Mock implements AuthRemoteDatasource {}

void main() {
  test('invalid recovery input never reaches Auth', () async {
    final remote = _Remote();
    final repository = AuthRepositoryImpl(remote);

    expect(
      (await repository.requestPasswordRecovery(email: 'not-an-email'))
          .isLeft(),
      isTrue,
    );
    expect(
      (await repository.completePasswordRecovery(
        email: 'a@example.test',
        code: '12',
        newPassword: 'newPassword1',
      )).isLeft(),
      isTrue,
    );
    expect(
      (await repository.completePasswordRecovery(
        email: 'a@example.test',
        code: '123456',
        newPassword: 'weak',
      )).isLeft(),
      isTrue,
    );
    verifyZeroInteractions(remote);
  });

  test('valid recovery data passes only to Auth', () async {
    final remote = _Remote();
    when(() => remote.requestPasswordRecovery(email: 'a@example.test'))
        .thenAnswer((_) async {});
    when(
      () => remote.completePasswordRecovery(
        email: 'a@example.test',
        code: '123456',
        newPassword: 'newPassword1',
      ),
    ).thenAnswer((_) async {});
    final repository = AuthRepositoryImpl(remote);

    expect(
      (await repository.requestPasswordRecovery(email: ' a@example.test '))
          .isRight(),
      isTrue,
    );
    expect(
      (await repository.completePasswordRecovery(
        email: ' a@example.test ',
        code: ' 123456 ',
        newPassword: 'newPassword1',
      )).isRight(),
      isTrue,
    );
    verify(() => remote.requestPasswordRecovery(email: 'a@example.test'))
        .called(1);
    verify(
      () => remote.completePasswordRecovery(
        email: 'a@example.test',
        code: '123456',
        newPassword: 'newPassword1',
      ),
    ).called(1);
  });
}
