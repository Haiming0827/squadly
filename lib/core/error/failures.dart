import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

/// 业务层统一错误类型
@freezed
sealed class Failure with _$Failure {
  const factory Failure.server({required String message}) = ServerFailure;
  const factory Failure.network({String? message}) = NetworkFailure;
  const factory Failure.unauthorized({String? message}) = UnauthorizedFailure;
  const factory Failure.notFound({String? message}) = NotFoundFailure;
  const factory Failure.squadFull() = SquadFullFailure;
  const factory Failure.squadMinMembers() = SquadMinMembersFailure;
  const factory Failure.permissionDenied({String? message}) =
      PermissionDeniedFailure;
  const factory Failure.validation({required String message}) =
      ValidationFailure;
  const factory Failure.unknown({String? message}) = UnknownFailure;
}
