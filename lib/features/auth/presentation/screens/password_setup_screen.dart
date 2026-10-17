import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

class PasswordSetupScreen extends ConsumerStatefulWidget {
  const PasswordSetupScreen({super.key});

  @override
  ConsumerState<PasswordSetupScreen> createState() =>
      _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends ConsumerState<PasswordSetupScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final sent = await ref
        .read(authNotifierProvider.notifier)
        .sendPasswordSetupVerification();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeSent = sent;
      if (!sent) _error = '验证码发送失败，请稍后重试';
    });
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = '请输入短信中的 6 位验证码');
      return;
    }
    if (!Validators.isValidPassword(password)) {
      setState(() => _error = '密码至少 8 位，且包含英文字母和数字');
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
    final saved = await ref
        .read(authNotifierProvider.notifier)
        .setPassword(code: code, password: password);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!saved) _error = '验证码无效或密码设置失败，请检查后重试';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置登录密码')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '手机号注册已完成。设置密码后，也可以使用手机号和密码登录。',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (_codeSent) ...[
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '短信验证码'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '登录密码',
                  helperText: '至少 8 位，包含英文字母和数字',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmationController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认密码'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const CircularProgressIndicator()
                    : const Text('保存密码'),
              ),
              TextButton(
                onPressed: _busy ? null : _sendCode,
                child: const Text('重新发送验证码'),
              ),
            ] else
              FilledButton(
                onPressed: _busy ? null : _sendCode,
                child: _busy
                    ? const CircularProgressIndicator()
                    : const Text('验证手机号并设置密码'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
