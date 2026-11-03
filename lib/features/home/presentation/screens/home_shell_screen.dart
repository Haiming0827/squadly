import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../app/providers/conversation_customization_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/squad_avatar.dart';
import '../../../conversation/presentation/conversation_settings_screen.dart';
import '../../../social/presentation/screens/circle_screen.dart';
import '../../../social/presentation/screens/data_workshop_screen.dart';
import '../../../social/presentation/screens/share_composer_screen.dart';
import '../../../squad/domain/entities/squad.dart';
import '../../../squad/presentation/screens/squad_list_screen.dart';
import 'demo_conversation_list_screen.dart';
import 'plan_hub_screen.dart';
import 'profile_screen.dart';
import 'profile_settings_screen.dart';

/// The social-first shell. The existing activity flows remain under Plan.
class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  int _index = 0;

  Future<void> _openComposer([String? itemId]) async {
    if (ref.read(demoAppStoreProvider).currentSquad == null) {
      setState(() => _index = 1);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('先创建或加入小队，再与伙伴分享')));
      return;
    }

    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ShareComposerScreen(initialItemId: itemId),
      ),
    );
    if (!mounted || published != true) return;
    setState(() => _index = 1);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已分享到小队')));
  }

  void _openConversation(Squad squad) {
    ref.read(demoAppStoreProvider.notifier).selectSquad(squad.id);
    unawaited(recordConversationOpen(ref, squad.id));
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Consumer(
          builder: (context, routeRef, _) {
            final current =
                routeRef
                    .watch(demoAppStoreProvider)
                    .mySquads
                    .where((s) => s.id == squad.id)
                    .firstOrNull ??
                squad;
            final pref = routeRef.watch(
              conversationPreferenceMapProvider,
            )[squad.id];
            return Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    SquadAvatar(
                      name: current.name,
                      avatar: current.avatarUrl,
                      radius: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pref?.displayName(current.name) ?? current.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: '会话设置',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => ConversationSettingsScreen(
                          squadId: squad.id,
                          onManageMembers: () async {
                            ref
                                .read(demoAppStoreProvider.notifier)
                                .selectSquad(squad.id);
                            final store = ref.read(
                              demoAppStoreProvider.notifier,
                            );
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(title: const Text('小队管理')),
                                  body: const SquadListScreen(),
                                ),
                              ),
                            );
                            if (mounted &&
                                ref
                                    .read(demoAppStoreProvider)
                                    .mySquads
                                    .any((s) => s.id == squad.id)) {
                              store.selectSquad(squad.id);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: CircleScreen(
                onCreatePost: _openComposer,
                initialView: CircleScreenView.chat,
                showViewSwitcher: false,
              ),
            );
          },
        ),
      ),
    );
  }

  void _openDataWorkshop() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('数据工坊')),
          body: DataWorkshopScreen(onShareItem: _openComposer),
        ),
      ),
    );
  }

  void _openSquadProfile(Squad squad) {
    ref.read(demoAppStoreProvider.notifier).selectSquad(squad.id);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ConversationSettingsScreen(
          squadId: squad.id,
          onManageMembers: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('小队管理')),
                body: const SquadListScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openProfileSettings() => openProfileSettings(
    context,
    onOpenDataWorkshop: _openDataWorkshop,
    onManageSquad: _openSquadProfile,
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoAppStoreProvider);
    final squad = state.currentSquad;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        automaticallyImplyLeading: false,
        leading: _index == 3
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 16),
                child: CircleAvatar(
                  backgroundColor: colors.surfaceContainerHigh,
                  foregroundColor: colors.onSurface,
                  child: squad == null
                      ? const Icon(Icons.groups_2_outlined, size: 20)
                      : Text(squad.name.characters.first),
                ),
              ),
        title: _index == 3
            ? const Text('个人主页')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    squad?.name ?? AppConstants.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '仅限邀请的小圈子 · 本地演示',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
        actions: [
          if (_index == 3)
            IconButton(
              tooltip: '设置',
              onPressed: _openProfileSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          if (_index != 3 && state.mySquads.length > 1)
            PopupMenuButton<String>(
              tooltip: '切换小队',
              icon: const Icon(Icons.swap_horiz_rounded),
              onSelected: (id) =>
                  ref.read(demoAppStoreProvider.notifier).selectSquad(id),
              itemBuilder: (_) => [
                for (final item in state.mySquads)
                  PopupMenuItem<String>(
                    value: item.id,
                    child: Row(
                      children: [
                        Icon(
                          item.id == squad?.id
                              ? Icons.check_rounded
                              : Icons.groups_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.name)),
                      ],
                    ),
                  ),
              ],
            ),
          if (_index != 3)
            IconButton(
              tooltip: '我的',
              onPressed: () => setState(() => _index = 3),
              icon: const Icon(Icons.account_circle_outlined),
            ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DemoConversationListScreen(
            onOpenConversation: _openConversation,
            onOpenSquads: () => setState(() => _index = 1),
          ),
          squad == null
              ? const SquadListScreen()
              : CircleScreen(
                  onCreatePost: _openComposer,
                  showViewSwitcher: false,
                  onOpenPlans: () => setState(() => _index = 2),
                ),
          PlanHubScreen(onOpenSquads: () => setState(() => _index = 1)),
          ProfileScreen(
            showSettingsButton: false,
            onOpenDataWorkshop: _openDataWorkshop,
            onManageSquad: _openSquadProfile,
          ),
        ],
      ),
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
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: '计划',
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
