import 'package:fpdart/fpdart.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/user.dart';
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
  Future<Either<Failure, User>> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    if (nickname.trim().isEmpty) {
      return const Left(Failure.validation(message: '请输入昵称'));
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
        nickname: nickname,
      ),
    );
  }

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
  Future<Either<Failure, User>> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    if (!Validators.isValidChinesePhone(phone)) {
      return const Left(Failure.validation(message: '请输入有效的手机号'));
    }
    if (code.trim().isEmpty) {
      return const Left(Failure.validation(message: '请输入验证码'));
    }
    return Right(_store.verifyPhoneCode(phone: phone, code: code));
  }

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
  Future<Either<Failure, Unit>> signOut() async {
    _store.signOut();
    return const Right(unit);
  }
}
