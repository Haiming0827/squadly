import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

/// 登录页面
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailCodeController = TextEditingController();

  bool _isRegister = false;
  bool _isPhoneMode = false;
  bool _codeSent = false;
  bool _awaitingEmailConfirmation = false;
  int _cooldownSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _emailCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AsyncLoading;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 80),
              // Logo 区域
              Icon(
                Icons.groups_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '小分队',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '小队同行，共筑理想日常',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),

              // 切换登录方式
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('邮箱登录')),
                  ButtonSegment(value: true, label: Text('手机登录')),
                ],
                selected: {_isPhoneMode},
                onSelectionChanged: (selected) {
                  setState(() {
                    _isPhoneMode = selected.first;
                    _codeSent = false;
                    _awaitingEmailConfirmation = false;
                  });
                },
              ),
              const SizedBox(height: 24),

              if (_isPhoneMode) ..._buildPhoneForm(isLoading),
              if (!_isPhoneMode) ..._buildEmailForm(isLoading),
              if (_awaitingEmailConfirmation && !_isPhoneMode)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    '验证码已发送到邮箱，请输入验证码完成注册。',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 24),

              if (Platform.isIOS) ...[
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '其他登录方式',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _handleAppleSignIn,
                  icon: const Icon(Icons.apple),
                  label: const Text('通过 Apple 登录'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],

              // 错误提示
              if (authState is AsyncError)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    authState.error is Failure
                        ? authFailureMessage(authState.error as Failure)
                        : '操作失败，请稍后重试',
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEmailForm(bool isLoading) {
    return [
      if (_isRegister)
        TextField(
          controller: _nicknameController,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: '昵称',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textInputAction: TextInputAction.next,
        ),
      if (_isRegister) const SizedBox(height: 12),
      TextField(
        controller: _emailController,
        decoration: const InputDecoration(
          labelText: '邮箱',
          prefixIcon: Icon(Icons.email_outlined),
        ),
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      if (!_awaitingEmailConfirmation)
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: '密码',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleEmailSubmit(),
        ),
      if (_awaitingEmailConfirmation) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _emailCodeController,
          decoration: const InputDecoration(labelText: '邮箱验证码'),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleEmailVerify(),
        ),
      ],
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: isLoading
            ? null
            : (_awaitingEmailConfirmation
                  ? _handleEmailVerify
                  : _handleEmailSubmit),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                _awaitingEmailConfirmation
                    ? '验证邮箱'
                    : (_isRegister ? '注册' : '登录'),
              ),
      ),
      if (!_awaitingEmailConfirmation)
        TextButton(
          onPressed: () => setState(() {
            _isRegister = !_isRegister;
            _awaitingEmailConfirmation = false;
          }),
          child: Text(_isRegister ? '已有账号？去登录' : '没有账号？去注册'),
        ),
      if (!_isRegister &&
          !const bool.fromEnvironment('USE_DEMO_BACKEND', defaultValue: true))
        TextButton(
          onPressed: isLoading ? null : () => context.go('/recover'),
          child: const Text('忘记密码？'),
        ),
    ];
  }

  void _handleEmailVerify() {
    final email = _emailController.text.trim();
    final code = _emailCodeController.text.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(code)) {
      _showError('请输入邮箱中的验证码');
      return;
    }
    ref
        .read(authNotifierProvider.notifier)
        .verifyEmailSignup(email: email, code: code);
  }

  List<Widget> _buildPhoneForm(bool isLoading) {
    return [
      TextField(
        controller: _phoneController,
        decoration: const InputDecoration(
          labelText: '手机号',
          prefixIcon: Icon(Icons.phone_outlined),
          prefixText: '+86 ',
        ),
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
      ),
      if (_codeSent) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: '验证码',
            prefixIcon: Icon(Icons.sms_outlined),
          ),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handlePhoneVerify(),
        ),
      ],
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: isLoading
            ? null
            : (_codeSent ? _handlePhoneVerify : _handleSendCode),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_codeSent ? '验证登录' : '发送验证码'),
      ),
      if (_codeSent)
        TextButton(
          onPressed: isLoading || _cooldownSeconds > 0 ? null : _handleSendCode,
          child: Text(
            _cooldownSeconds > 0 ? '${_cooldownSeconds}s 后可重发' : '重新发送验证码',
          ),
        ),
    ];
  }

  void _handleEmailSubmit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!Validators.isValidEmail(email)) {
      _showError('请输入有效的邮箱地址');
      return;
    }
    if (!Validators.isValidPassword(password)) {
      _showError('密码至少 8 位，包含字母和数字');
      return;
    }

    final notifier = ref.read(authNotifierProvider.notifier);
    if (_isRegister) {
      final nickname = _nicknameController.text.trim();
      if (nickname.isEmpty) {
        _showError('请输入昵称');
        return;
      }
      notifier
          .signUpWithEmail(email: email, password: password, nickname: nickname)
          .then((needsConfirmation) {
            if (mounted && needsConfirmation) {
              setState(() {
                _awaitingEmailConfirmation = true;
                _isRegister = false;
              });
            }
          });
    } else {
      notifier.signInWithEmail(email: email, password: password);
    }
  }

  void _handleSendCode() {
    final phone = _phoneController.text.trim();
    if (!Validators.isValidChinesePhone(phone)) {
      _showError('请输入有效的手机号');
      return;
    }

    ref
        .read(authNotifierProvider.notifier)
        .sendPhoneVerification(phone: phone)
        .then((success) {
          if (success && mounted) {
            setState(() {
              _codeSent = true;
              _cooldownSeconds = 60;
            });
            _resendTimer?.cancel();
            _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!mounted) {
                timer.cancel();
                return;
              }
              setState(() {
                _cooldownSeconds--;
                if (_cooldownSeconds <= 0) timer.cancel();
              });
            });
          }
        });
  }

  void _handlePhoneVerify() {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError('请输入验证码');
      return;
    }
    ref
        .read(authNotifierProvider.notifier)
        .verifyPhoneCode(phone: phone, code: code);
  }

  void _handleAppleSignIn() {
    ref.read(authNotifierProvider.notifier).signInWithApple();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
