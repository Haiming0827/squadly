import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/squad_provider.dart';

/// A link may be opened before login; the router returns here after auth.
class InvitationLandingScreen extends ConsumerStatefulWidget {
  const InvitationLandingScreen({super.key, required this.credential});

  final String credential;

  @override
  ConsumerState<InvitationLandingScreen> createState() =>
      _InvitationLandingScreenState();
}

class _InvitationLandingScreenState
    extends ConsumerState<InvitationLandingScreen> {
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redeem());
  }

  Future<void> _redeem() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(squadRepositoryProvider)
        .redeemInvitation(credential: widget.credential);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _error = squadFailureMessage(failure);
        _busy = false;
      }),
      (squad) {
        ref.read(selectedSquadIdProvider.notifier).state = squad.id;
        ref.invalidate(mySquadsProvider);
        ref.invalidate(squadMembersProvider(squad.id));
        context.go('/');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('加入小队')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('正在验证邀请…'),
              ] else ...[
                Text(_error ?? '加入失败', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _redeem, child: const Text('重试')),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('返回小队'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
