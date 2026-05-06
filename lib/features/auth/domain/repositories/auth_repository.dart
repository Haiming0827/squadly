import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/user.dart';

/// 认证仓库接口
abstract class AuthRepository {
  /// 邮箱密码登录
  Future<Either<Failure, User>> signInWithEmail({
    required String email,
    required String password,
  });

  /// 邮箱注册
  Future<Either<Failure, User>> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  });

  /// 手机号验证码登录
  Future<Either<Failure, Unit>> sendPhoneVerification({required String phone});

  Future<Either<Failure, User>> verifyPhoneCode({
    required String phone,
    required String code,
  });

  /// Apple 登录
  Future<Either<Failure, User>> signInWithApple();

  /// 获取当前用户
  Future<Either<Failure, User>> getCurrentUser();

  /// 退出登录
  Future<Either<Failure, Unit>> signOut();
}
