import 'package:cloudbase_flutter/cloudbase_flutter.dart'
    hide CloudBaseConfig, User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/cloudbase_client_provider.dart';
import '../../../notifications/push_registration_provider.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/demo_auth_repository.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

final phonePasswordSetupRequiredProvider = StateProvider<bool>((ref) => false);

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
  return AuthRemoteDatasource(
    ref.watch(cloudBaseAppProvider),
    ref.watch(cloudBasePostgresClientProvider).rest,
  );
}

/// 认证仓库 Provider
@riverpod
AuthRepository authRepository(Ref ref) {
  final useDemoBackend = ref.watch(useDemoBackendProvider);
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
    final useDemoBackend = ref.watch(useDemoBackendProvider);
    if (useDemoBackend) {
      final demoState = ref.watch(demoAppStoreProvider);
      return AsyncData(demoState.currentUser);
    }

    // Keep the repository/data source alive while the login flow is active.
    // CloudBase returns an in-memory OTP verifier callback that must survive
    // the separate send-code and verify-code button taps.
    ref.watch(authRepositoryProvider);

    ref.listen(cloudBaseAuthStateChangesProvider, (prev, next) {
      next.whenData((authState) {
        if (authState.session == null) {
          ref.read(phonePasswordSetupRequiredProvider.notifier).state = false;
          state = const AsyncData(null);
        } else {
          _loadCurrentUser();
        }
      });
    });
    Future.microtask(_loadCurrentUser);
    // Session restoration is background work. It must not disable login
    // actions while CloudBase refreshes or the device is offline.
    return const AsyncData(null);
  }

  Future<void> _loadCurrentUser() async {
    final app = ref.read(cloudBaseAppProvider);
    final sessionResponse = await app.auth.getSession().timeout(
      const Duration(seconds: 8),
      onTimeout: () => SignInRes(error: AuthError(code: 'session_timeout')),
    );
    if (!sessionResponse.isSuccess) {
      if (sessionResponse.error?.code == 'no_session') {
        ref.read(phonePasswordSetupRequiredProvider.notifier).state = false;
        state = const AsyncData(null);
        return;
      }
      state = AsyncError(
        sessionResponse.error ?? StateError('CloudBase session unavailable'),
        StackTrace.current,
      );
      return;
    }
    final sessionToken = sessionResponse.data?.session?.accessToken;
    if (sessionToken == null) {
      ref.read(phonePasswordSetupRequiredProvider.notifier).state = false;
      state = const AsyncData(null);
      return;
    }
    var needsPasswordSetup = false;
    try {
      needsPasswordSetup = await ref
          .read(authRemoteDatasourceProvider)
          .currentUserNeedsPasswordSetup()
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
    } catch (_) {
      // Password setup status must never prevent a valid session from loading.
    }
    ref.read(phonePasswordSetupRequiredProvider.notifier).state =
        needsPasswordSetup;
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.getCurrentUser().timeout(
      const Duration(seconds: 8),
      onTimeout: () => const Left(Failure.network()),
    );
    // A recovery OTP signs in briefly. Its profile request may finish after
    // the recovery session has been closed; never revive that stale identity.
    final currentSession = await app.auth.getSession().timeout(
      const Duration(seconds: 8),
      onTimeout: () => SignInRes(error: AuthError(code: 'session_timeout')),
    );
    if (currentSession.data?.session?.accessToken != sessionToken) return;
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

  Future<void> verifyEmailSignup({
    required String email,
    required String code,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .verifyEmailSignup(email: email, code: code);
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (user) => AsyncData(user),
    );
  }

  Future<Failure?> verifyEmailChange({required String code}) async {
    final result = await ref
        .read(authRepositoryProvider)
        .verifyEmailChange(code: code);
    return result.fold((failure) => failure, (user) {
      state = AsyncData(user);
      return null;
    });
  }

  /// 发送手机验证码
  Future<bool> sendPhoneVerification({required String phone}) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final Either<Failure, Unit> result;
    try {
      // CloudBase's Dio client already owns the 30-second network timeout.
      // A matching timeout here races the SDK and hides its actual error code.
      result = await repo.sendPhoneVerification(phone: phone);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
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
    final result = await repo
        .verifyPhoneCode(phone: phone, code: code)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => const Left(Failure.network()),
        );
    state = result.fold((failure) => AsyncError(failure, StackTrace.current), (
      authResult,
    ) {
      ref.read(phonePasswordSetupRequiredProvider.notifier).state =
          authResult.needsPasswordSetup;
      return AsyncData(authResult.user);
    });
  }

  Future<bool> sendPasswordSetupVerification() async {
    final result = await ref
        .read(authRepositoryProvider)
        .sendPasswordSetupVerification()
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => const Left(Failure.network()),
        );
    return result.fold((_) => false, (_) => true);
  }

  Future<bool> setPassword({
    required String code,
    required String password,
  }) async {
    final result = await ref
        .read(authRepositoryProvider)
        .setPassword(code: code, password: password)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => const Left(Failure.network()),
        );
    return result.fold((_) => false, (_) {
      ref.read(phonePasswordSetupRequiredProvider.notifier).state = false;
      state = AsyncData(state.valueOrNull);
      return true;
    });
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
