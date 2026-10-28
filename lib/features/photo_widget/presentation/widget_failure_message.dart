import '../../../core/error/failures.dart';

String widgetFailureMessage(Failure failure) => switch (failure) {
  ServerFailure(:final message) || ValidationFailure(:final message) => message,
  UnauthorizedFailure(:final message) => message ?? '请重新登录',
  PermissionDeniedFailure(:final message) => message ?? '没有小队访问权限',
  NotFoundFailure(:final message) => message ?? '原照片已无法查看',
  NetworkFailure(:final message) => message ?? '网络暂不可用，请重试',
  _ => '组件暂不可用，请重试',
};
