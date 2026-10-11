import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../notifications/push_registration_provider.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/demo_auth_repository.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

String authFailureMessage(Failure failure) => switch (failure) {
  ServerFailure(:final message) => message,
  ValidationFailure(:final message) => message,
  UnauthorizedFailure() => '请先登录',
  NetworkFailure() => '网络连接失败，请稍后重试',
  PermissionDeniedFailure() => '没有操作权限',
  NotFoundFailure() => '没有找到账号',
  SquadFullFailure() || SquadMinMembersFailure() => '操作失败，请稍后重试',
  UnknownFailure() => '操作失败，请稍后重试',
};

/// 认证数据源 Provider
@riverpod
AuthRemoteDatasource authRemoteDatasource(Ref ref) {
  return AuthRemoteDatasource(ref.watch(supabaseClientProvider));
}

/// 认证仓库 Provider
@riverpod
AuthRepository authRepository(Ref ref) {
  const useDemoBackend = bool.fromEnvironment(
    'USE_DEMO_BACKEND',
    defaultValue: true,
  );
  if (useDemoBackend) {
    return DemoAuthRepository(ref.watch(demoAppStoreProvider.notifier));
  }
  return AuthRepositoryImpl(ref.watch(authRemoteDatasourceProvider));
}

/// 认证状态 Notifier
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<User?> build() {
    const useDemoBackend = bool.fromEnvironment(
      'USE_DEMO_BACKEND',
      defaultValue: true,
    );
    if (useDemoBackend) {
      final demoState = ref.watch(demoAppStoreProvider);
      return AsyncData(demoState.currentUser);
    }

    ref.listen(authStateChangesProvider, (prev, next) {
      next.whenData((authState) {
        if (authState.session == null) {
          state = const AsyncData(null);
        } else {
          _loadCurrentUser();
        }
      });
    });
    if (ref.read(supabaseClientProvider).auth.currentSession != null) {
      Future.microtask(_loadCurrentUser);
      return const AsyncLoading();
    }
    return const AsyncData(null);
  }

  Future<void> _loadCurrentUser() async {
    final client = ref.read(supabaseClientProvider);
    final sessionToken = client.auth.currentSession?.accessToken;
    if (sessionToken == null) return;
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.getCurrentUser();
    // A recovery OTP signs in briefly. Its profile request may finish after
    // the recovery session has been closed; never revive that stale identity.
    if (client.auth.currentSession?.accessToken != sessionToken) return;
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (user) => AsyncData(user),
    );
  }

  Future<void> refreshCurrentUser() => _loadCurrentUser();

  /// Preserve the signed-in session state when a profile edit fails.
  Future<Failure?> updateNickname(String nickname) async {
    final result = await ref
        .read(authRepositoryProvider)
        .updateNickname(nickname: nickname);
    return result.fold((failure) => failure, (user) {
      state = AsyncData(user);
      return null;
    });
  }

  /// 邮箱登录
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signInWithEmail(email: email, password: password);
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (user) => AsyncData(user),
    );
  }

  /// 邮箱注册
  /// Returns true when a confirmation email must be opened before login.
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signUpWithEmail(
      email: email,
      password: password,
      nickname: nickname,
    );
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (user) {
        state = AsyncData(user);
        return user == null;
      },
    );
  }

  /// 发送手机验证码
  Future<bool> sendPhoneVerification({required String phone}) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.sendPhoneVerification(phone: phone);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }

  /// 验证手机验证码
  Future<void> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.verifyPhoneCode(phone: phone, code: code);
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (user) => AsyncData(user),
    );
  }

  /// Apple 登录
  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signInWithApple();
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (user) => AsyncData(user),
    );
  }

  /// 退出登录
  Future<void> signOut() async {
    const useDemoBackend = bool.fromEnvironment(
      'USE_DEMO_BACKEND',
      defaultValue: true,
    );
    if (!useDemoBackend) {
      try {
        await ref.read(pushRegistrationProvider).unregister();
      } catch (_) {
        // Sign-out remains available offline. Push payloads contain no private
        // content, and the old token is reassigned on the next login.
      }
    }
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signOut();
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (_) => state = const AsyncData(null),
    );
  }
}
