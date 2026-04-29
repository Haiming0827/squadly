import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/squad.dart';
import '../entities/squad_member.dart';

/// 小队仓库接口
abstract class SquadRepository {
  /// 创建小队
  Future<Either<Failure, Squad>> createSquad({
    required String name,
    String? description,
  });

  /// 获取我的小队列表
  Future<Either<Failure, List<Squad>>> getMySquads();

  /// 通过邀请码加入小队
  Future<Either<Failure, Squad>> joinSquad({required String inviteCode});

  /// 获取小队成员列表
  Future<Either<Failure, List<SquadMember>>> getSquadMembers({
    required String squadId,
  });

  /// 移除成员（仅队长）
  Future<Either<Failure, Unit>> removeMember({
    required String squadId,
    required String userId,
  });

  /// 退出小队
  Future<Either<Failure, Unit>> leaveSquad({required String squadId});

  /// 转让队长
  Future<Either<Failure, Unit>> transferCaptain({
    required String squadId,
    required String newCaptainId,
  });
}
