import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

/// Uses a recovery email OTP so this flow does not depend on an unverified
/// universal-link domain. The hosted recovery template must show .Token.
class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  ConsumerState<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState
    extends ConsumerState<PasswordRecoveryScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (!Validators.isValidEmail(email)) {
      setState(() => _error = '请输入有效的邮箱地址');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .requestPasswordRecovery(email: email);
      if (!mounted) return;
      result.match(
        (failure) => setState(() => _error = authFailureMessage(failure)),
        (_) {
          setState(() => _sent = true);
          _startCooldown();
        },
      );
    } catch (_) {
      if (mounted) setState(() => _error = '请求失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    if (!Validators.isValidEmail(email)) {
      setState(() => _error = '请输入有效的邮箱地址');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = '请输入邮件中的 6 位验证码');
      return;
    }
    if (!Validators.isValidPassword(password)) {
      setState(() => _error = '密码至少 8 位，包含字母和数字');
      return;
    }
    if (password != _confirmationController.text) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .completePasswordRecovery(
            email: email,
            code: code,
            newPassword: password,
          );
      if (!mounted) return;
      result.match(
        (failure) => setState(() => _error = authFailureMessage(failure)),
        (_) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('密码已更新，请重新登录')));
          context.go('/login');
        },
      );
    } catch (_) {
      if (mounted) setState(() => _error = '重置失败，请重新申请验证码');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('找回密码')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                enabled: !_sent && !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: '注册邮箱'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || (_sent && _cooldownSeconds > 0)
                    ? null
                    : _requestCode,
                child: Text(
                  _sent && _cooldownSeconds > 0
                      ? '${_cooldownSeconds}s 后可重发'
                      : _sent
                      ? '重新发送验证码'
                      : '发送验证码',
                ),
              ),
              if (_sent) ...[
                const SizedBox(height: 16),
                Text('如该邮箱已注册，验证码会发送到邮箱。', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 20),
                TextField(
                  controller: _codeController,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: '邮件验证码'),
                ),
                TextField(
                  controller: _passwordController,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '新密码'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmationController,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '确认新密码'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _complete,
                  child: const Text('确认重置'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
