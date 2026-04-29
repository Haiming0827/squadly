import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user.dart';
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
  Future<Either<Failure, User>> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    try {
      final dto = await _remoteDatasource.signUpWithEmail(
        email: email,
        password: password,
        nickname: nickname,
      );
      return Right(dto.toEntity());
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
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
  Future<Either<Failure, User>> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    try {
      final dto = await _remoteDatasource.verifyPhoneCode(
        phone: phone,
        code: code,
      );
      return Right(dto.toEntity());
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
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
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _remoteDatasource.signOut();
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    }
  }
}
