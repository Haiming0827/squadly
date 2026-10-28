import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/conversation_runtime_providers.dart';
import '../../../../app/providers/current_user_provider.dart';
import '../../../../app/providers/photo_providers.dart';
import '../../../../app/providers/photo_widget_providers.dart';
import '../../../../app/providers/social_providers.dart';
import '../../../../app/providers/squad_context_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cards/presentation/card_composer_screen.dart';
import '../../../cards/presentation/card_detail_sheet.dart';
import '../../../conversation/domain/conversation_target.dart';
import '../../../conversation/presentation/conversation_list_screen.dart';
import '../../../conversation/presentation/conversation_screen.dart';
import '../../../notifications/domain/push_registration.dart';
import '../../../notifications/push_registration_provider.dart';
import '../../../photo_widget/presentation/photo_widget_settings_screen.dart';
import '../../../photos/domain/photo.dart';
import '../../../photos/presentation/photo_composer_screen.dart';
import '../../../photos/presentation/photo_message_view.dart';
import '../../../plan/domain/entities/squad_plan.dart';
import '../../../secure_route/presentation/route_device_screen.dart';
import '../../../social/presentation/screens/data_workshop_screen.dart';
import '../../../social/presentation/screens/remote_share_composer_screen.dart';
import '../../../social/presentation/screens/social_feed_screen.dart';
import '../../../squad/domain/entities/squad.dart';
import '../../../squad/presentation/screens/squad_list_screen.dart';
import 'plan_hub_screen.dart';
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
  ProviderSubscription<dynamic>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = ref.listenManual(authNotifierProvider, (
      previous,
      next,
    ) {
      if (next.value != null) unawaited(_registerPush());
    });
    if (ref.read(authNotifierProvider).value != null) {
      unawaited(_registerPush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_registerPush());
  }

  Future<void> _registerPush() async {
    if (ref.read(authNotifierProvider).value == null) return;
    try {
      await ref.read(pushRegistrationProvider).register();
    } catch (_) {
      // Reattempt on the next authenticated app launch. No token is logged.
    }
  }

  Future<void> _manageNotifications() async {
    late final PushRegistrationResult result;
    try {
      result = await ref
          .read(pushRegistrationProvider)
          .register(requestPermission: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暂时无法更新通知设置')));
      return;
    }
    if (!mounted) return;
    final message = switch (result) {
      PushRegistrationResult.registered => '已开启消息通知',
      PushRegistrationResult.permissionRequired => '请在系统设置中允许 Squadly 发送通知',
      PushRegistrationResult.unavailable => '此设备或当前版本暂不支持消息通知',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openComposer(String squadId, String squadName) async {
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CardComposerScreen(squadId: squadId, squadName: squadName),
      ),
    );
    if (!mounted || published != true) return;
    await ref
        .read(
          conversationControllerProvider(ConversationTarget(squadId: squadId))
              .notifier,
        )
        .refresh();
  }

  Future<void> _openSocialComposer([String? itemId]) async {
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RemoteShareComposerScreen(initialItemId: itemId),
      ),
    );
    if (!mounted || published != true) return;
    final squadId = ref.read(currentSquadProvider).value?.id;
    if (squadId != null) ref.invalidate(squadSocialPostsProvider(squadId));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已发布小队动态')));
  }

  Future<void> _openPhotoComposer(
    Squad squad, {
    String? replyToMessageId,
  }) async {
    final userId = ref.read(currentUserProvider).asData?.value?.id;
    if (userId == null || !ref.read(photoSendingAvailableProvider)) return;
    final target = PhotoTarget(
      userId: userId,
      squadId: squad.id,
      squadName: squad.name,
      replyToMessageId: replyToMessageId,
    );
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PhotoComposerScreen(key: ValueKey(target), target: target),
      ),
    );
    if (!mounted ||
        published != true ||
        ref.read(currentUserProvider).asData?.value?.id != userId) {
      return;
    }
    await _refreshPhotos(squad.id);
    if (mounted) ref.invalidate(remoteConversationSummariesProvider);
  }

  Future<void> _refreshPhotos(String squadId) async {
    final controller = ref.read(
      conversationControllerProvider(ConversationTarget(squadId: squadId))
          .notifier,
    );
    await controller.refresh();
    if (!mounted) return;
    await controller.reloadRecent();
    if (!mounted || ref.read(photoWidgetContextProvider) == null) return;
    final widgets = ref.read(photoWidgetServiceProvider);
    final state = (await widgets.read()).getRight().toNullable();
    if (state?.binding?.squadId == squadId &&
        state?.binding?.previewEnabled == true) {
      await widgets.refresh(expectedBinding: state!.binding!.id);
    }
  }

  void _openDataWorkshop() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('数据工坊')),
          body: DataWorkshopScreen(
            onShareItem: (id) => _openSocialComposer(id),
          ),
        ),
      ),
    );
  }

  Future<void> _openConversation(Squad squad) async {
    ref.read(selectedSquadIdProvider.notifier).state = squad.id;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (conversationContext) => Consumer(
          builder: (context, routeRef, _) {
            final photosAvailable = routeRef.watch(
              photoSendingAvailableProvider,
            );
            return Scaffold(
              appBar: AppBar(title: Text(squad.name)),
              body: ConversationScreen(
                key: ValueKey(squad.id),
                squadId: squad.id,
                squadName: squad.name,
                onCreateCard: () => _openComposer(squad.id, squad.name),
                onCreatePhoto: photosAvailable
                    ? () => _openPhotoComposer(squad)
                    : null,
                photoBuilder: (_, entry, canRead, onDisplayChanged) =>
                    PhotoMessageView(
                      key: ValueKey(entry.id),
                      squadId: squad.id,
                      messageId: entry.id,
                      authorId: entry.authorId,
                      photo: entry.photo!,
                      canRead: canRead,
                      onDisplayChanged: onDisplayChanged,
                      onChanged: () => unawaited(_refreshPhotos(squad.id)),
                      onReplyPhoto:
                          photosAvailable && entry.photo?.isRevoked == false
                          ? () => _openPhotoComposer(
                              squad,
                              replyToMessageId: entry.id,
                            )
                          : null,
                    ),
                onOpenCard: (entry) {
                  showModalBottomSheet<void>(
                    context: conversationContext,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => CardDetailSheet(
                      squadId: squad.id,
                      squadName: squad.name,
                      entry: entry,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    if (mounted) {
      ref.invalidate(remoteConversationSummariesProvider);
      ref.invalidate(squadRecentSharesProvider(squad.id));
    }
  }

  Future<void> _openPlanConversation(ConversationListItem item) async {
    final plan = item.plan;
    if (plan == null) return;
    await _pushPlanConversation(item.squad, plan);
    if (mounted) ref.invalidate(remoteConversationSummariesProvider);
  }

  Future<void> _openPlanDiscussion(SquadPlan plan) async {
    final squads = await ref.read(mySquadsProvider.future);
    if (!mounted) return;
    final squad = squads.where((item) => item.id == plan.squadId).firstOrNull;
    if (squad == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法找到计划所属小队')));
      return;
    }
    await _pushPlanConversation(squad, plan);
  }

  Future<void> _pushPlanConversation(Squad squad, SquadPlan plan) async {
    ref.read(selectedSquadIdProvider.notifier).state = squad.id;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(plan.title)),
          body: ConversationScreen(
            key: ValueKey('plan-thread-${plan.id}'),
            squadId: squad.id,
            squadName: squad.name,
            planId: plan.id,
            planTitle: plan.title,
            onCreateCard: () {},
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final squad = ref.watch(currentSquadProvider);
    final current = squad.value;
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
            onPressed: () => setState(() => _index = 3),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: switch (_index) {
        0 => ConversationListScreen(
          onOpenConversation: _openConversation,
          onOpenPlanConversation: _openPlanConversation,
          onOpenSquads: () => setState(() => _index = 1),
        ),
        1 => RemoteSquadListScreen(
          onOpenPhotoWidget: (squad) => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => PhotoWidgetSettingsScreen(
                squadId: squad.id,
                squadName: squad.name,
              ),
            ),
          ),
          onOpenConversation: (squad) => _openConversation(squad),
          onOpenPlans: () => setState(() => _index = 2),
          socialFeedBuilder: (squadId) => SocialFeedSection(
            squadId: squadId,
            onOpenFeed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => SocialFeedScreen(squadId: squadId),
              ),
            ),
          ),
        ),
        2 => PlanHubScreen(
          onOpenSquads: () => setState(() => _index = 1),
          onOpenPlanDiscussion: _openPlanDiscussion,
        ),
        _ => ProfileScreen(
          onOpenDataWorkshop: _openDataWorkshop,
          onManageNotifications: _manageNotifications,
        ),
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
