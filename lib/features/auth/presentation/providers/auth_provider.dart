import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/demo_auth_repository.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

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

    return const AsyncData(null);
  }

  Future<void> _loadCurrentUser() async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.getCurrentUser();
    state = result.fold(
      (failure) => const AsyncData(null),
      (user) => AsyncData(user),
    );
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
  Future<void> signUpWithEmail({
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
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (user) => AsyncData(user),
    );
  }

  /// 发送手机验证码
  Future<bool> sendPhoneVerification({required String phone}) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.sendPhoneVerification(phone: phone);
    return result.isRight();
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
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = const AsyncData(null);
  }
}
