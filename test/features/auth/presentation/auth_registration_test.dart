import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/auth/domain/repositories/auth_repository.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';

class _AuthBoundary extends Mock implements AuthRepository {}

void main() {
  test(
    'email signup without a session stays on login for confirmation',
    () async {
      final repository = _AuthBoundary();
      when(
        () => repository.signUpWithEmail(
          email: 'a@example.test',
          password: 'password1',
          nickname: '阿青',
        ),
      ).thenAnswer((_) async => const Right(null));
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final needsConfirmation = await container
          .read(authNotifierProvider.notifier)
          .signUpWithEmail(
            email: 'a@example.test',
            password: 'password1',
            nickname: '阿青',
          );

      expect(needsConfirmation, isTrue);
      expect(container.read(authNotifierProvider).value, isNull);
    },
  );

  test('phone send failure remains visible to the registration UI', () async {
    final repository = _AuthBoundary();
    when(() => repository.sendPhoneVerification(phone: '13800138000'))
        .thenAnswer((_) async => const Left(Failure.server(message: '发送过于频繁')));
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final sent = await container
        .read(authNotifierProvider.notifier)
        .sendPhoneVerification(phone: '13800138000');

    expect(sent, isFalse);
    expect(container.read(authNotifierProvider).hasError, isTrue);
  });
}
