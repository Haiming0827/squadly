import 'package:fpdart/fpdart.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/user.dart';
import '../../domain/public_nickname.dart';
import '../../domain/repositories/auth_repository.dart';

class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this._store);

  final DemoAppStore _store;

  @override
  Future<Either<Failure, User>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!Validators.isValidEmail(email)) {
      return const Left(Failure.validation(message: '请输入有效的邮箱地址'));
    }
    if (!Validators.isValidPassword(password)) {
      return const Left(Failure.validation(message: '密码至少 8 位，包含字母和数字'));
    }
    return Right(_store.signInWithEmail(email: email, password: password));
  }

  @override
  Future<Either<Failure, User?>> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final normalized = normalizePublicNickname(nickname);
    if (normalized == null) {
      return const Left(Failure.validation(message: '昵称需为 1–60 字，不能含换行或控制字符'));
    }
    if (!Validators.isValidEmail(email)) {
      return const Left(Failure.validation(message: '请输入有效的邮箱地址'));
    }
    if (!Validators.isValidPassword(password)) {
      return const Left(Failure.validation(message: '密码至少 8 位，包含字母和数字'));
    }
    return Right(
      _store.signUpWithEmail(
        email: email,
        password: password,
        nickname: normalized,
      ),
    );
  }

  @override
  Future<Either<Failure, User>> verifyEmailSignup({
    required String email,
    required String code,
  }) async => const Left(Failure.server(message: '演示模式不需要邮箱验证码'));

  @override
  Future<Either<Failure, Unit>> requestPasswordRecovery({
    required String email,
  }) async => const Left(Failure.server(message: '演示模式不发送找回密码邮件'));

  @override
  Future<Either<Failure, Unit>> completePasswordRecovery({
    required String email,
    required String code,
    required String newPassword,
  }) async => const Left(Failure.server(message: '演示模式不支持找回密码'));

  @override
  Future<Either<Failure, Unit>> sendPhoneVerification({
    required String phone,
  }) async {
    if (!Validators.isValidChinesePhone(phone)) {
      return const Left(Failure.validation(message: '请输入有效的手机号'));
    }
    _store.sendPhoneVerification(phone: phone);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, PhoneAuthResult>> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    if (!Validators.isValidChinesePhone(phone)) {
      return const Left(Failure.validation(message: '请输入有效的手机号'));
    }
    if (code.trim().isEmpty) {
      return const Left(Failure.validation(message: '请输入验证码'));
    }
    return Right(
      PhoneAuthResult(
        user: _store.verifyPhoneCode(phone: phone, code: code),
        needsPasswordSetup: false,
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> sendPasswordSetupVerification() async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> setPassword({
    required String code,
    required String password,
  }) async => const Right(unit);

  @override
  Future<Either<Failure, Unit>> requestEmailChange({
    required String email,
  }) async => const Left(Failure.server(message: '演示模式不支持修改联系方式'));

  @override
  Future<Either<Failure, User>> verifyEmailChange({
    required String code,
  }) async => const Left(Failure.server(message: '演示模式不支持修改联系方式'));

  @override
  Future<Either<Failure, Unit>> requestPhoneChange({
    required String phone,
  }) async => const Left(Failure.server(message: '演示模式不支持绑定手机号'));

  @override
  Future<Either<Failure, Unit>> resendPhoneChange({
    required String phone,
  }) async => const Left(Failure.server(message: '演示模式不支持绑定手机号'));

  @override
  Future<Either<Failure, User>> verifyPhoneChange({
    required String phone,
    required String code,
  }) async => const Left(Failure.server(message: '演示模式不支持绑定手机号'));

  @override
  Future<Either<Failure, User>> signInWithApple() async {
    return Right(_store.signInWithApple());
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    final user = _store.getCurrentUser();
    if (user == null) {
      return const Left(Failure.unauthorized(message: '请先登录'));
    }
    return Right(user);
  }

  @override
  Future<Either<Failure, User>> updateNickname({
    required String nickname,
  }) async {
    final normalized = normalizePublicNickname(nickname);
    if (normalized == null) {
      return const Left(Failure.validation(message: '昵称需为 1–60 字，不能含换行或控制字符'));
    }
    try {
      return Right(_store.updateNickname(normalized));
    } on StateError {
      return const Left(Failure.unauthorized(message: '请先登录'));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    _store.signOut();
    return const Right(unit);
  }
}
