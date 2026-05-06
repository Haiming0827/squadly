import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_dto.dart';

/// 认证远程数据源
class AuthRemoteDatasource {
  final sb.SupabaseClient _client;

  AuthRemoteDatasource(this._client);

  /// 邮箱密码注册
  Future<UserDto> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const ServerException(
          message: 'Sign up failed: no user returned',
        );
      }

      // 创建 profile 记录
      await _client.from(SupabaseConstants.profiles).insert({
        'id': user.id,
        'nickname': nickname,
        'email': email,
      });

      return _fetchProfile(user.id);
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 邮箱密码登录
  Future<UserDto> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const ServerException(
          message: 'Sign in failed: no user returned',
        );
      }

      return _fetchProfile(user.id);
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 发送手机验证码
  Future<void> sendPhoneVerification({required String phone}) async {
    try {
      await _client.auth.signInWithOtp(phone: phone);
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 验证手机验证码
  Future<UserDto> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: code,
        type: sb.OtpType.sms,
      );

      final user = response.user;
      if (user == null) {
        throw const ServerException(
          message: 'Phone verification failed: no user returned',
        );
      }

      // 检查 profile 是否存在，不存在则创建
      final existing = await _client
          .from(SupabaseConstants.profiles)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        await _client.from(SupabaseConstants.profiles).insert({
          'id': user.id,
          'nickname': '用户${phone.substring(phone.length - 4)}',
          'phone': phone,
        });
      }

      return _fetchProfile(user.id);
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// Apple 登录
  Future<UserDto> signInWithApple() async {
    try {
      await _client.auth.signInWithOAuth(sb.OAuthProvider.apple);

      final user = _client.auth.currentUser;
      if (user == null) {
        throw const ServerException(
          message: 'Apple sign in failed: no user returned',
        );
      }

      // 检查 profile 是否存在
      final existing = await _client
          .from(SupabaseConstants.profiles)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        final email = user.email ?? '';
        await _client.from(SupabaseConstants.profiles).insert({
          'id': user.id,
          'nickname': email.split('@').first,
          'email': email,
        });
      }

      return _fetchProfile(user.id);
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 获取当前用户 profile
  Future<UserDto> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ServerException(
        message: 'No authenticated user',
        statusCode: 401,
      );
    }
    return _fetchProfile(user.id);
  }

  /// 退出登录
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 更新用户 profile
  Future<UserDto> updateProfile({
    required String userId,
    String? nickname,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (nickname != null) updates['nickname'] = nickname;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    await _client
        .from(SupabaseConstants.profiles)
        .update(updates)
        .eq('id', userId);

    return _fetchProfile(userId);
  }

  Future<UserDto> _fetchProfile(String userId) async {
    final data = await _client
        .from(SupabaseConstants.profiles)
        .select()
        .eq('id', userId)
        .single();

    return UserDto.fromJson(data);
  }
}
