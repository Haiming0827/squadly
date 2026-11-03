import 'package:cloudbase_flutter/cloudbase_flutter.dart' hide CloudBaseConfig;
import 'package:postgrest/postgrest.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/cloudbase_auth_gate.dart';
import '../../domain/chinese_phone.dart';
import '../models/user_dto.dart';

/// CloudBase Auth adapter. Verification callbacks/message IDs stay in memory
/// for the active screen flow and are never persisted as credentials.
class AuthRemoteDatasource {
  AuthRemoteDatasource(this._app, this._client);

  final CloudBase _app;
  CloudBaseAuthGate get _gate => CloudBaseAuthGate.forAuth(_app.auth);
  final PostgrestClient _client;

  Future<SignInRes> Function(VerifyOtpParams)? _emailSignupVerifier;
  Future<SignInRes> Function(VerifyOtpParams)? _phoneLoginVerifier;
  Future<SignInRes> Function(UpdateUserAttributes)? _passwordRecoveryVerifier;
  Future<GetUserRes> Function(UpdateUserVerifyParams)? _phoneChangeVerifier;
  Future<GetUserRes> Function(UpdateUserVerifyParams)? _emailChangeVerifier;
  Future<SignInRes> Function(UpdateUserAttributes)? _passwordSetupVerifier;
  String? _pendingSignupNickname;
  String? _phoneChangeMessageId;
  String? _pendingPhoneChange;
  String? _pendingEmailChange;

  Future<UserDto?> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final response = await _gate.mutate(
      () => _app.auth.signUp(
        SignUpReq(email: email.trim(), password: password, nickname: nickname),
      ),
    );
    if (!response.isSuccess) _throwAuth(response.error);
    final verifier = response.data?.verifyOtp;
    if (verifier == null) {
      throw const ServerException(message: 'CloudBase 未返回邮箱验证码流程');
    }
    _emailSignupVerifier = verifier;
    _pendingSignupNickname = nickname;
    return null;
  }

  Future<UserDto> verifyEmailSignup({
    required String email,
    required String code,
  }) async {
    final verifier = _emailSignupVerifier;
    if (verifier == null) {
      throw const ServerException(message: '请重新提交注册信息');
    }
    final response = await _gate.mutate(
      () => verifier(VerifyOtpParams(token: code.trim())),
    );
    if (!response.isSuccess) _throwAuth(response.error);
    final user = response.data?.user;
    if (user?.id == null) {
      throw const ServerException(message: '邮箱验证未建立登录会话');
    }
    _emailSignupVerifier = null;
    final nickname = _pendingSignupNickname;
    _pendingSignupNickname = null;
    if (nickname != null) {
      return updateNickname(nickname: nickname);
    }
    return _fetchProfile(user!);
  }

  Future<UserDto> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _gate.mutate(
      () => _app.auth.signInWithPassword(
        SignInWithPasswordReq(email: email.trim(), password: password),
      ),
    );
    if (!response.isSuccess) _throwAuth(response.error);
    final user = response.data?.user;
    if (user?.id == null) throw const ServerException(message: '登录未建立会话');
    return _fetchProfile(user!);
  }

  Future<void> requestPasswordRecovery({required String email}) async {
    final response = await _gate.mutate(
      () => _app.auth.resetPasswordForEmail(email.trim()),
    );
    if (!response.isSuccess) _throwAuth(response.error);
    final verifier = response.data?.updateUser;
    if (verifier == null) {
      throw const ServerException(message: 'CloudBase 未返回密码重置流程');
    }
    _passwordRecoveryVerifier = verifier;
  }

  Future<void> completePasswordRecovery({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final verifier = _passwordRecoveryVerifier;
    if (verifier == null) {
      throw const ServerException(message: '请重新申请密码重置验证码');
    }
    final response = await _gate.mutate(() async {
      // Do not call the gate recursively from this SDK transaction.
      final existing = await _app.auth.getSession();
      if (!existing.isSuccess && existing.error?.code != 'no_session') {
        _throwAuth(existing.error);
      }
      if (existing.data?.session != null) {
        throw const ServerException(message: '请先退出当前账号，再找回密码');
      }
      final verified = await verifier(
        UpdateUserAttributes(nonce: code.trim(), password: newPassword),
      );
      if (verified.isSuccess) await _app.auth.signOut();
      return verified;
    });
    if (!response.isSuccess) _throwAuth(response.error);
    _passwordRecoveryVerifier = null;
  }

  Future<void> sendPhoneVerification({required String phone}) async {
    final normalized = ChinesePhone.toE164(phone);
    final response = await _gate.mutate(
      () => _app.auth.signInWithOtp(
        SignInWithOtpReq(
          phone: normalized,
          options: SignInWithOtpOptions(shouldCreateUser: true),
        ),
      ),
    );
    if (!response.isSuccess) _throwAuth(response.error);
    final verifier = response.data?.verifyOtp;
    if (verifier == null) throw const ServerException(message: '短信验证码未发送');
    _phoneLoginVerifier = verifier;
  }

  Future<(UserDto, bool)> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    final verifier = _phoneLoginVerifier;
    if (verifier == null) throw const ServerException(message: '请重新发送验证码');
    final response = await _gate.mutate(
      () => verifier(VerifyOtpParams(token: code.trim())),
    );
    if (!response.isSuccess) _throwAuth(response.error);
    final user = response.data?.user;
    if (user?.id == null) throw const ServerException(message: '手机号验证未建立会话');
    _phoneLoginVerifier = null;
    final profileResponse = await _gate.read(() => _app.auth.getUser());
    if (!profileResponse.isSuccess) _throwAuth(profileResponse.error);
    final currentUser = profileResponse.data?.user ?? user!;
    final needsPasswordSetup = currentUser.userMetadata?.hasPassword == false;
    return (await _fetchProfile(currentUser), needsPasswordSetup);
  }

  Future<bool> currentUserNeedsPasswordSetup() async {
    final response = await _gate.read(() => _app.auth.getUser());
    if (!response.isSuccess) _throwAuth(response.error);
    return response.data?.user?.userMetadata?.hasPassword == false;
  }

  Future<void> sendPasswordSetupVerification() async {
    final response = await _gate.mutate(() => _app.auth.reauthenticate());
    if (!response.isSuccess) _throwAuth(response.error);
    final verifier = response.data?.updateUser;
    if (verifier == null) {
      throw const ServerException(message: 'CloudBase 未返回密码设置验证流程');
    }
    _passwordSetupVerifier = verifier;
  }

  Future<void> setPassword({
    required String code,
    required String password,
  }) async {
    final verifier = _passwordSetupVerifier;
    if (verifier == null) {
      throw const ServerException(message: '请先获取密码设置验证码');
    }
    final response = await _gate.mutate(
      () => verifier(
        UpdateUserAttributes(nonce: code.trim(), password: password),
      ),
    );
    if (!response.isSuccess) _throwAuth(response.error);
    _passwordSetupVerifier = null;
  }

  Future<void> requestEmailChange({required String email}) async {
    final response = await _gate.mutate(
      () => _app.auth.updateUser(UpdateUserReq(email: email.trim())),
    );
    if (!response.isSuccess) _throwAuth(response.error);
    final verifier = response.data?.verifyOtp;
    if (verifier == null) {
      throw const ServerException(message: 'CloudBase 未返回邮箱验证流程');
    }
    _emailChangeVerifier = verifier;
    _pendingEmailChange = email.trim();
  }

  Future<UserDto> verifyEmailChange({required String code}) async {
    final verifier = _emailChangeVerifier;
    final email = _pendingEmailChange;
    if (verifier == null || email == null) {
      throw const ServerException(message: '请重新申请邮箱验证码');
    }
    final response = await _gate.mutate(
      () => verifier(UpdateUserVerifyParams(token: code.trim(), email: email)),
    );
    if (!response.isSuccess) _throwAuth(response.error);
    final user = response.data?.user ?? (await _currentSession())?.user;
    if (user?.id == null) throw const ServerException(message: '邮箱验证未完成');
    _emailChangeVerifier = null;
    _pendingEmailChange = null;
    return _fetchProfile(user!);
  }

  Future<void> requestPhoneChange({required String phone}) async {
    final normalized = ChinesePhone.toE164(phone);
    final response = await _gate.mutate(
      () => _app.auth.updateUser(UpdateUserReq(phone: normalized)),
    );
    if (!response.isSuccess) _throwAuth(response.error);
    _phoneChangeVerifier = response.data?.verifyOtp;
    _phoneChangeMessageId = response.data?.messageId;
    _pendingPhoneChange = normalized;
    if (_phoneChangeVerifier == null && _phoneChangeMessageId == null) {
      throw const ServerException(message: 'CloudBase 未返回手机号验证流程');
    }
  }

  Future<void> resendPhoneChange({required String phone}) async {
    final normalized = ChinesePhone.toE164(phone);
    if (_pendingPhoneChange != normalized) {
      throw const ServerException(message: '请重新申请手机号验证码');
    }
    final response = await _gate.mutate(
      () => _app.auth.resend(
        ResendReq(phone: normalized, type: ResendType.phoneChange),
      ),
    );
    if (!response.isSuccess) _throwAuth(response.error);
    _phoneChangeMessageId = response.data?.messageId;
  }

  Future<UserDto> verifyPhoneChange({
    required String phone,
    required String code,
  }) async {
    final normalized = ChinesePhone.toE164(phone);
    if (_pendingPhoneChange != normalized) {
      throw const ServerException(message: '请重新申请手机号验证码');
    }
    final messageId = _phoneChangeMessageId;
    if (messageId == null) throw const ServerException(message: '请重新申请手机号验证码');
    final response = await _gate.mutate(
      () => _app.auth.verifyOtp(
        VerifyOtpReq(
          phone: normalized,
          token: code.trim(),
          messageId: messageId,
          type: VerifyOtpType.phoneChange,
        ),
      ),
    );
    if (!response.isSuccess) _throwAuth(response.error);
    final user = response.data?.user ?? (await _currentSession())?.user;
    if (user?.id == null) throw const ServerException(message: '请先登录后绑定手机号');
    _phoneChangeVerifier = null;
    _emailChangeVerifier = null;
    _pendingEmailChange = null;
    _phoneChangeMessageId = null;
    _pendingPhoneChange = null;
    return (await _fetchProfile(user!)).copyWith(phone: normalized);
  }

  Future<UserDto> signInWithApple() async => throw const ServerException(
    message: 'CloudBase Flutter SDK 尚未提供带 nonce 校验的 Apple 登录接口',
  );

  Future<UserDto> getCurrentUser() async {
    final user = (await _currentSession())?.user;
    if (user?.id == null) {
      throw const ServerException(
        message: 'No authenticated user',
        statusCode: 401,
      );
    }
    return _fetchProfile(user!);
  }

  Future<void> signOut() async {
    final response = await _gate.mutate(() => _app.auth.signOut());
    if (!response.isSuccess) _throwAuth(response.error);
    _clearPendingVerifications();
  }

  Future<UserDto> updateNickname({required String nickname}) async {
    final user = (await _currentSession())?.user;
    if (user?.id == null) {
      throw const ServerException(message: '请先登录', statusCode: 401);
    }
    try {
      final data = await _client
          .from('profiles')
          .update({'nickname': nickname})
          .eq('id', user!.id!)
          .select('id,nickname,avatar_url,created_at')
          .single();
      return UserDto.fromJson(data)
          .copyWith(email: user.email, phone: user.phone);
    } on PostgrestException catch (error) {
      throw ServerException(message: error.message);
    }
  }

  Future<UserDto> _fetchProfile(User user) async {
    try {
      final data = await _client
          .from('profiles')
          .select('id,nickname,avatar_url,created_at')
          .eq('id', user.id!)
          .single();
      return UserDto.fromJson(data)
          .copyWith(email: user.email, phone: user.phone);
    } on PostgrestException catch (error) {
      throw ServerException(message: error.message);
    }
  }

  Future<Session?> _currentSession() async {
    final response = await _gate.session();
    if (!response.isSuccess) {
      if (response.error?.code == 'no_session') return null;
      _throwAuth(response.error);
    }
    return response.data?.session;
  }

  void _clearPendingVerifications() {
    _emailSignupVerifier = null;
    _pendingSignupNickname = null;
    _phoneLoginVerifier = null;
    _passwordRecoveryVerifier = null;
    _phoneChangeVerifier = null;
    _phoneChangeMessageId = null;
    _pendingPhoneChange = null;
    _emailChangeVerifier = null;
    _pendingEmailChange = null;
    _passwordSetupVerifier = null;
  }

  Never _throwAuth(AuthError? error) {
    final message = error?.message ?? 'CloudBase Auth 请求失败';
    if (message.toLowerCase().contains('provider email not found')) {
      throw const ServerException(
        message: '当前 CloudBase 环境未启用邮箱登录，请在「身份认证 → 登录方式」中开启邮箱登录并配置邮件服务。',
      );
    }
    if (message.contains('手机号验证码登录') &&
        (message.contains('身份源') || message.contains('登录方式'))) {
      throw const ServerException(
        message:
            '当前 CloudBase 环境未启用手机号验证码登录，请环境管理员在「身份认证 → 登录方式」中开启；该能力仅支持上海地域。',
      );
    }
    final code = error?.code;
    if (code == 'timeout' || code == 'unreachable') {
      final status = error?.status == null ? '' : '（HTTP ${error!.status}）';
      throw ServerException(
        message: '连接 CloudBase 验证服务失败：$message；错误码 $code$status',
        statusCode: error?.status,
      );
    }
    throw ServerException(message: message, statusCode: error?.status);
  }
}
