import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/user.dart';
import '../../domain/public_nickname.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_mapper.dart';

/// 认证仓库实现
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remoteDatasource;

  AuthRepositoryImpl(this._remoteDatasource);

  @override
  Future<Either<Failure, User>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final dto = await _remoteDatasource.signInWithEmail(
        email: email,
        password: password,
      );
      return Right(dto.toEntity());
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
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
    try {
      final dto = await _remoteDatasource.signUpWithEmail(
        email: email,
        password: password,
        nickname: normalized,
      );
      return Right(dto?.toEntity());
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, User>> verifyEmailSignup({
    required String email,
    required String code,
  }) async {
    try {
      return Right(
        (await _remoteDatasource.verifyEmailSignup(
          email: email,
          code: code,
        )).toEntity(),
      );
    } on ServerException catch (error) {
      return Left(Failure.server(message: error.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, Unit>> requestPasswordRecovery({
    required String email,
  }) async {
    if (!Validators.isValidEmail(email.trim())) {
      return const Left(Failure.validation(message: '请输入有效的邮箱地址'));
    }
    try {
      await _remoteDatasource.requestPasswordRecovery(email: email.trim());
      return const Right(unit);
    } on ServerException catch (error) {
      return Left(Failure.server(message: error.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, Unit>> completePasswordRecovery({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (!Validators.isValidEmail(email.trim())) {
      return const Left(Failure.validation(message: '请输入有效的邮箱地址'));
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      return const Left(Failure.validation(message: '请输入邮件中的 6 位验证码'));
    }
    if (!Validators.isValidPassword(newPassword)) {
      return const Left(Failure.validation(message: '密码至少 8 位，包含字母和数字'));
    }
    try {
      await _remoteDatasource.completePasswordRecovery(
        email: email.trim(),
        code: code.trim(),
        newPassword: newPassword,
      );
      return const Right(unit);
    } on ServerException catch (error) {
      return Left(Failure.server(message: error.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, Unit>> sendPhoneVerification({
    required String phone,
  }) async {
    try {
      await _remoteDatasource.sendPhoneVerification(phone: phone);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, PhoneAuthResult>> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    try {
      final result = await _remoteDatasource.verifyPhoneCode(
        phone: phone,
        code: code,
      );
      return Right(
        PhoneAuthResult(
          user: result.$1.toEntity(),
          needsPasswordSetup: result.$2,
        ),
      );
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, Unit>> sendPasswordSetupVerification() async {
    try {
      await _remoteDatasource.sendPasswordSetupVerification();
      return const Right(unit);
    } on ServerException catch (error) {
      return Left(Failure.server(message: error.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, Unit>> setPassword({
    required String code,
    required String password,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      return const Left(Failure.validation(message: '请输入 6 位验证码'));
    }
    if (!Validators.isValidPassword(password)) {
      return const Left(Failure.validation(message: '密码至少 8 位，包含字母和数字'));
    }
    try {
      await _remoteDatasource.setPassword(code: code, password: password);
      return const Right(unit);
    } on ServerException catch (error) {
      return Left(Failure.server(message: error.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, Unit>> requestEmailChange({
    required String email,
  }) async {
    try {
      await _remoteDatasource.requestEmailChange(email: email);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    }
  }

  @override
  Future<Either<Failure, User>> verifyEmailChange({
    required String code,
  }) async {
    try {
      return Right(
        (await _remoteDatasource.verifyEmailChange(code: code)).toEntity(),
      );
    } on ServerException catch (error) {
      return Left(Failure.server(message: error.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, Unit>> requestPhoneChange({
    required String phone,
  }) async {
    try {
      await _remoteDatasource.requestPhoneChange(phone: phone);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> resendPhoneChange({
    required String phone,
  }) async {
    try {
      await _remoteDatasource.resendPhoneChange(phone: phone);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    }
  }

  @override
  Future<Either<Failure, User>> verifyPhoneChange({
    required String phone,
    required String code,
  }) async {
    try {
      final dto = await _remoteDatasource.verifyPhoneChange(
        phone: phone,
        code: code,
      );
      return Right(dto.toEntity());
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithApple() async {
    try {
      final dto = await _remoteDatasource.signInWithApple();
      return Right(dto.toEntity());
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      final dto = await _remoteDatasource.getCurrentUser();
      return Right(dto.toEntity());
    } on ServerException catch (e) {
      if (e.statusCode == 401) {
        return const Left(Failure.unauthorized());
      }
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
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
      final dto = await _remoteDatasource.updateNickname(nickname: normalized);
      return Right(dto.toEntity());
    } on ServerException catch (error) {
      return Left(Failure.server(message: error.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _remoteDatasource.signOut();
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    }
  }
}
