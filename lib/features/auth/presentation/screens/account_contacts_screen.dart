import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

/// Only the signed-in person can open this route. Contacts come from Auth,
/// never a squad member projection.
class AccountContactsScreen extends ConsumerStatefulWidget {
  const AccountContactsScreen({super.key});

  @override
  ConsumerState<AccountContactsScreen> createState() =>
      _AccountContactsScreenState();
}

class _AccountContactsScreenState extends ConsumerState<AccountContactsScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _resendTimer;
  int _cooldownSeconds = 0;
  bool _codeSent = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('请先登录')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('账号与联系方式')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('仅你自己可以查看和管理这里的联系方式。'),
            const SizedBox(height: 24),
            Text('邮箱', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(user.email ?? '尚未绑定'),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: '新邮箱地址'),
              keyboardType: TextInputType.emailAddress,
              enabled: !_busy,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _requestEmailChange,
              child: const Text('发送邮箱修改确认'),
            ),
            const Divider(height: 40),
            Text('手机号', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(user.phone ?? '尚未绑定'),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '中国大陆手机号',
                prefixText: '+86 ',
              ),
              keyboardType: TextInputType.phone,
              enabled: !_busy && !_codeSent,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy || _codeSent ? null : _requestPhoneChange,
              child: Text(user.phone == null ? '发送绑定验证码' : '发送更换验证码'),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: '短信验证码'),
                keyboardType: TextInputType.number,
                enabled: !_busy,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _verifyPhoneChange,
                child: const Text('确认手机号'),
              ),
              TextButton(
                onPressed: _busy || _cooldownSeconds > 0
                    ? null
                    : _resendPhoneChange,
                child: Text(
                  _cooldownSeconds > 0
                      ? '${_cooldownSeconds}s 后可重发'
                      : '重新发送验证码',
                ),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _requestEmailChange() async {
    final email = _emailController.text.trim();
    if (!Validators.isValidEmail(email)) {
      setState(() => _message = '请输入有效的邮箱地址');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .requestEmailChange(email: email);
      if (!mounted) return;
      result.fold(
        (failure) => setState(() => _message = authFailureMessage(failure)),
        (_) => setState(() => _message = '确认邮件已发送。完成验证前，原邮箱仍用于登录。'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPhoneChange() async {
    if (!Validators.isValidChinesePhone(_phoneController.text.trim())) {
      setState(() => _message = '请输入有效的中国大陆手机号');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .requestPhoneChange(phone: _phoneController.text.trim());
      if (!mounted) return;
      result.fold(
        (failure) => setState(() => _message = authFailureMessage(failure)),
        (_) {
          setState(() {
            _codeSent = true;
            _message = '验证码已发送到新手机号';
          });
          _startCooldown();
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendPhoneChange() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .resendPhoneChange(phone: _phoneController.text.trim());
      if (!mounted) return;
      result.fold(
        (failure) => setState(() => _message = authFailureMessage(failure)),
        (_) {
          setState(() => _message = '验证码已重新发送');
          _startCooldown();
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyPhoneChange() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(code)) {
      setState(() => _message = '请输入短信中的验证码');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .verifyPhoneChange(phone: _phoneController.text.trim(), code: code);
      if (!mounted) return;
      result.fold(
        (failure) => setState(() => _message = authFailureMessage(failure)),
        (_) {
          setState(() {
            _codeSent = false;
            _message = '手机号已验证';
            _codeController.clear();
          });
          ref.read(authNotifierProvider.notifier).refreshCurrentUser();
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCooldown() {
    _resendTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
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
}
