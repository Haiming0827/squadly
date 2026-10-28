import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';

class PhoneAuthResult {
  const PhoneAuthResult({required this.user, required this.needsPasswordSetup});

  final User user;
  final bool needsPasswordSetup;
}

/// 认证仓库接口
abstract class AuthRepository {
  /// 邮箱密码登录
  Future<Either<Failure, User>> signInWithEmail({
    required String email,
    required String password,
  });

  /// 邮箱注册
  /// Returns null when email confirmation is required and no session exists.
  Future<Either<Failure, User?>> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  });

  Future<Either<Failure, User>> verifyEmailSignup({
    required String email,
    required String code,
  });

  /// Always show the same user-facing result, whether or not the address is
  /// registered. The staging recovery template must contain an OTP code.
  Future<Either<Failure, Unit>> requestPasswordRecovery({
    required String email,
  });

  /// Consumes a recovery OTP, changes the password, then closes that session.
  Future<Either<Failure, Unit>> completePasswordRecovery({
    required String email,
    required String code,
    required String newPassword,
  });

  /// 手机号验证码登录
  Future<Either<Failure, Unit>> sendPhoneVerification({required String phone});

  Future<Either<Failure, PhoneAuthResult>> verifyPhoneCode({
    required String phone,
    required String code,
  });

  Future<Either<Failure, Unit>> sendPasswordSetupVerification();

  Future<Either<Failure, Unit>> setPassword({
    required String code,
    required String password,
  });

  /// Changes contacts on the existing authenticated account, never by
  /// signing in or guessing a second account's identity.
  Future<Either<Failure, Unit>> requestEmailChange({required String email});

  Future<Either<Failure, User>> verifyEmailChange({required String code});

  Future<Either<Failure, Unit>> requestPhoneChange({required String phone});

  Future<Either<Failure, Unit>> resendPhoneChange({required String phone});

  Future<Either<Failure, User>> verifyPhoneChange({
    required String phone,
    required String code,
  });

  /// Apple 登录
  Future<Either<Failure, User>> signInWithApple();

  /// 获取当前用户
  Future<Either<Failure, User>> getCurrentUser();

  /// Edits only the signed-in user's public nickname.
  Future<Either<Failure, User>> updateNickname({required String nickname});

  /// 退出登录
  Future<Either<Failure, Unit>> signOut();
}
