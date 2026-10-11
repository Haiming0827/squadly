import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cards/presentation/card_composer_screen.dart';
import '../../../conversation/presentation/conversation_provider.dart';
import '../../../conversation/presentation/conversation_screen.dart';
import '../../../notifications/push_registration_provider.dart';
import '../../../secure_route/presentation/route_device_screen.dart';
import '../../../squad/presentation/providers/squad_provider.dart';
import '../../../squad/presentation/screens/squad_list_screen.dart';
import 'profile_screen.dart';

/// The real-backend shell contains no DemoAppStore reads or demo content.
final class RemoteHomeShellScreen extends ConsumerStatefulWidget {
  const RemoteHomeShellScreen({super.key});

  @override
  ConsumerState<RemoteHomeShellScreen> createState() =>
      _RemoteHomeShellScreenState();
}

final class _RemoteHomeShellScreenState
    extends ConsumerState<RemoteHomeShellScreen>
    with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // APNs may prompt once; failure must never prevent opening the conversation.
    unawaited(_registerPush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_registerPush());
  }

  Future<void> _registerPush() async {
    try {
      await ref.read(pushRegistrationProvider).register();
    } catch (_) {
      // Reattempt on the next authenticated app launch. No token is logged.
    }
  }

  Future<void> _openComposer(String squadId, String squadName) async {
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CardComposerScreen(squadId: squadId, squadName: squadName),
      ),
    );
    if (!mounted || published != true) return;
    await ref.read(conversationControllerProvider(squadId).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final squad = ref.watch(currentSquadProvider);
    final current = squad.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(current?.name ?? '小分队'),
        actions: [
          if (current != null)
            IconButton(
              tooltip: '路线设备',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const RouteDeviceScreen()),
              ),
              icon: const Icon(Icons.verified_user_outlined),
            ),
          IconButton(
            tooltip: '我的',
            onPressed: () => setState(() => _index = 2),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: switch (_index) {
        0 => squad.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: OutlinedButton(
              onPressed: () => ref.invalidate(mySquadsProvider),
              child: const Text('小队加载失败，点击重试'),
            ),
          ),
          data: (selected) => selected == null
              ? Center(
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _index = 1),
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('先创建或加入小队'),
                  ),
                )
              : ConversationScreen(
                  key: ValueKey(selected.id),
                  squadId: selected.id,
                  squadName: selected.name,
                  onCreateCard: () => _openComposer(selected.id, selected.name),
                ),
        ),
        1 => const RemoteSquadListScreen(),
        _ => const ProfileScreen(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: '会话',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: '小队',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
