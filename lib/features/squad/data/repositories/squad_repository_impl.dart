import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/squad.dart';
import '../../domain/entities/squad_member.dart';
import '../../domain/repositories/squad_repository.dart';
import '../datasources/squad_remote_datasource.dart';
import '../models/squad_mapper.dart';

/// 小队仓库实现
class SquadRepositoryImpl implements SquadRepository {
  final SquadRemoteDatasource _remoteDatasource;

  SquadRepositoryImpl(this._remoteDatasource);

  @override
  Future<Either<Failure, Squad>> createSquad({
    required String name,
    String? description,
  }) async {
    try {
      final dto = await _remoteDatasource.createSquad(
        name: name,
        description: description,
      );
      return Right(dto.toEntity());
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, List<Squad>>> getMySquads() async {
    try {
      final dtos = await _remoteDatasource.getMySquads();
      return Right(dtos.map((d) => d.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, Squad>> joinSquad({required String inviteCode}) async {
    try {
      final dto = await _remoteDatasource.joinSquad(inviteCode: inviteCode);
      return Right(dto.toEntity());
    } on ServerException catch (e) {
      if (e.message.contains('已满员')) {
        return const Left(Failure.squadFull());
      }
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, List<SquadMember>>> getSquadMembers({
    required String squadId,
  }) async {
    try {
      final dtos = await _remoteDatasource.getSquadMembers(squadId: squadId);
      return Right(dtos.map((d) => d.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, Unit>> removeMember({
    required String squadId,
    required String userId,
  }) async {
    try {
      await _remoteDatasource.removeMember(squadId: squadId, userId: userId);
      return const Right(unit);
    } on ServerException catch (e) {
      if (e.message.contains('至少需要 2 人')) {
        return const Left(Failure.squadMinMembers());
      }
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, Unit>> leaveSquad({required String squadId}) async {
    try {
      await _remoteDatasource.leaveSquad(squadId: squadId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, Unit>> transferCaptain({
    required String squadId,
    required String newCaptainId,
  }) async {
    try {
      await _remoteDatasource.transferCaptain(
        squadId: squadId,
        newCaptainId: newCaptainId,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(Failure.server(message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    }
  }
}
