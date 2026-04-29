import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/fund_transaction.dart';
import '../entities/private_asset.dart';
import '../entities/public_fund.dart';
import '../entities/shared_expense.dart';

/// 理财仓库接口
abstract class FinanceRepository {
  // === 公共基金 ===
  Future<Either<Failure, PublicFund>> createFund({
    required String squadId,
    required String name,
    required String fundType,
    double targetAmount = 0,
  });

  Future<Either<Failure, List<PublicFund>>> getSquadFunds({
    required String squadId,
  });

  Future<Either<Failure, FundTransaction>> addFundTransaction({
    required String fundId,
    required double amount,
    String? description,
  });

  Future<Either<Failure, List<FundTransaction>>> getFundTransactions({
    required String fundId,
  });

  /// 暴露给旅行模块的接口
  Future<Either<Failure, double>> getFundBalance({required String fundId});

  // === 个人私密资产 ===
  Future<Either<Failure, PrivateAsset>> createPrivateAsset({
    required String assetType,
    required String name,
    double amount = 0,
    String? note,
  });

  Future<Either<Failure, List<PrivateAsset>>> getMyPrivateAssets();

  Future<Either<Failure, PrivateAsset>> updatePrivateAsset({
    required String assetId,
    String? name,
    double? amount,
    String? note,
  });

  Future<Either<Failure, Unit>> deletePrivateAsset({required String assetId});

  // === 集体记账 ===
  Future<Either<Failure, SharedExpense>> recordSharedExpense({
    required String squadId,
    required double amount,
    required String category,
    String? description,
    bool needsApproval = false,
  });

  Future<Either<Failure, List<SharedExpense>>> getSquadExpenses({
    required String squadId,
    DateTime? from,
    DateTime? to,
  });
}
