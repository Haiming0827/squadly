import '../../../core/error/failures.dart';

String photoFailureMessage(Failure failure) => switch (failure) {
  ServerFailure(:final message) || ValidationFailure(:final message) => message,
  PermissionDeniedFailure(:final message) => message ?? '没有小队访问权限',
  UnauthorizedFailure(:final message) => message ?? '请重新登录',
  NotFoundFailure(:final message) => message ?? '照片已撤回或无法查看',
  NetworkFailure(:final message) => message ?? '网络暂不可用，请稍后重试',
  _ => '照片暂不可用，请稍后重试',
};
