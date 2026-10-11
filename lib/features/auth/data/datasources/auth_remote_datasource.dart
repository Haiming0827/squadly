import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/chinese_phone.dart';
import '../models/user_dto.dart';
import 'apple_identity_gateway.dart';

/// 认证远程数据源
class AuthRemoteDatasource {
  final sb.SupabaseClient _client;
  final AppleIdentityGateway _appleIdentity;
  final bool _isIOS;

  AuthRemoteDatasource(
    this._client, {
    AppleIdentityGateway? appleIdentity,
    bool? isIOS,
  }) : _appleIdentity = appleIdentity ?? const NativeAppleIdentityGateway(),
       _isIOS = isIOS ?? Platform.isIOS;

  /// 邮箱密码注册
  Future<UserDto?> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'nickname': nickname.trim()},
      );

      final user = response.user;
      if (user == null) {
        throw const ServerException(
          message: 'Sign up failed: no user returned',
        );
      }

      // The auth.users trigger owns profile creation. A confirmed session may
      // not exist yet, so do not try an RLS-protected profile read or insert.
      if (response.session == null) return null;
      return await _fetchProfile(user.id);
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

      return await _fetchProfile(user.id);
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  Future<void> requestPasswordRecovery({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on sb.AuthException catch (error) {
      throw ServerException(message: error.message);
    }
  }

  /// Verify before changing a password. A successful OTP verification creates
  /// a temporary Auth session; always close it, even if the update fails.
  Future<void> completePasswordRecovery({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (_client.auth.currentSession != null) {
      throw const ServerException(message: '请先退出当前账号，再找回密码');
    }
    sb.AuthResponse response;
    try {
      response = await _client.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: sb.OtpType.recovery,
      );
    } on sb.AuthException {
      throw const ServerException(message: '验证码错误或已过期，请重新检查');
    }
    if (response.session == null || response.user == null) {
      throw const ServerException(message: '验证码错误或已过期，请重新检查');
    }
    try {
      await _client.auth.updateUser(sb.UserAttributes(password: newPassword));
    } on sb.AuthException {
      throw const ServerException(message: '密码更新失败，请重新申请验证码');
    } finally {
      await _client.auth.signOut(scope: sb.SignOutScope.local);
    }
  }

  /// 发送手机验证码
  Future<void> sendPhoneVerification({required String phone}) async {
    try {
      await _client.auth.signInWithOtp(phone: ChinesePhone.toE164(phone));
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    } on FormatException catch (e) {
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
        phone: ChinesePhone.toE164(phone),
        token: code,
        type: sb.OtpType.sms,
      );

      final user = response.user;
      if (user == null) {
        throw const ServerException(
          message: 'Phone verification failed: no user returned',
        );
      }

      return await _fetchProfile(user.id);
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    } on FormatException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// Starts a verified contact change on the current Auth identity.
  Future<void> requestEmailChange({required String email}) async {
    try {
      await _client.auth.updateUser(sb.UserAttributes(email: email.trim()));
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  Future<void> requestPhoneChange({required String phone}) async {
    try {
      await _client.auth.updateUser(
        sb.UserAttributes(phone: ChinesePhone.toE164(phone)),
      );
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    } on FormatException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  Future<void> resendPhoneChange({required String phone}) async {
    try {
      await _client.auth.resend(
        phone: ChinesePhone.toE164(phone),
        type: sb.OtpType.phoneChange,
      );
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    } on FormatException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  Future<UserDto> verifyPhoneChange({
    required String phone,
    required String code,
  }) async {
    try {
      final normalized = ChinesePhone.toE164(phone);
      final response = await _client.auth.verifyOTP(
        phone: normalized,
        token: code,
        type: sb.OtpType.phoneChange,
      );
      final user = response.user ?? _client.auth.currentUser;
      if (user == null) {
        throw const ServerException(message: '请先登录后绑定手机号');
      }
      final profile = await _fetchProfile(user.id);
      return profile.copyWith(phone: user.phone ?? normalized);
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    } on FormatException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// Apple 登录
  Future<UserDto> signInWithApple() async {
    if (!_isIOS) {
      throw const ServerException(message: 'Apple 登录仅支持 iPhone');
    }
    try {
      final rawNonce = _client.auth.generateRawNonce();
      final hash = await Sha256().hash(utf8.encode(rawNonce));
      final hashedNonce = hash.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      final idToken = await _appleIdentity.requestIdToken(
        hashedNonce: hashedNonce,
      );
      if (idToken == null || idToken.isEmpty) {
        throw const ServerException(message: 'Apple 未返回身份凭证，请重试');
      }
      final response = await _client.auth.signInWithIdToken(
        provider: sb.OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      final user = response.user;
      if (user == null) {
        throw const ServerException(message: 'Apple 登录未建立会话，请重试');
      }
      return await _fetchProfile(user.id);
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

  /// The authenticated identity, not a caller-provided ID, owns this write.
  Future<UserDto> updateNickname({required String nickname}) async {
    final ownAuthUser = _client.auth.currentUser;
    if (ownAuthUser == null) {
      throw const ServerException(message: '请先登录', statusCode: 401);
    }
    try {
      final data = await _client
          .from(SupabaseConstants.profiles)
          .update({'nickname': nickname})
          .eq('id', ownAuthUser.id)
          .select('id,nickname,avatar_url,created_at')
          .single();
      return UserDto.fromJson(
        data,
      ).copyWith(email: ownAuthUser.email, phone: ownAuthUser.phone);
    } on sb.PostgrestException catch (error) {
      throw ServerException(message: error.message);
    }
  }

  Future<UserDto> _fetchProfile(String userId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.profiles)
          .select('id,nickname,avatar_url,created_at')
          .eq('id', userId)
          .single();
      final ownAuthUser = _client.auth.currentUser;
      final profile = UserDto.fromJson(data);
      if (ownAuthUser?.id != userId) return profile;
      return profile.copyWith(
        email: ownAuthUser?.email,
        phone: ownAuthUser?.phone,
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }
}
