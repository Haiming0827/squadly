import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/current_user_provider.dart';
import '../../../../app/providers/personal_home_providers.dart';
import '../../../../shared/widgets/squad_avatar.dart';
import '../../../squad/domain/entities/squad.dart';
import 'profile_settings_screen.dart';
import 'profile_showcase_widgets.dart';

/// The owner's visual home. Configuration belongs to the Settings hierarchy.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    this.onOpenDataWorkshop,
    this.onManageNotifications,
    this.onManageRouteDevice,
    this.onManageSquad,
    this.showSettingsButton = true,
    super.key,
  });
  final VoidCallback? onOpenDataWorkshop,
      onManageNotifications,
      onManageRouteDevice;
  final ValueChanged<Squad>? onManageSquad;
  final bool showSettingsButton;

  void _open(BuildContext context, ProfileSettingsSection section) =>
      openProfileSettings(
        context,
        section: section,
        onOpenDataWorkshop: onOpenDataWorkshop,
        onManageNotifications: onManageNotifications,
        onManageRouteDevice: onManageRouteDevice,
        onManageSquad: onManageSquad,
      );
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final nickname = user?.nickname.trim().isNotEmpty == true
        ? user!.nickname.trim()
        : '朋友';
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final squads = ref.watch(personalHomeSquadsProvider);
    return ListView(
      key: const ValueKey('personal-home'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSettingsButton)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: '设置',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () =>
                          _open(context, ProfileSettingsSection.root),
                    ),
                  ),
                Semantics(
                  button: true,
                  label: '编辑个人资料',
                  child: InkWell(
                    key: const ValueKey('profile-identity'),
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _open(context, ProfileSettingsSection.account),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.outlineVariant),
                            ),
                            child: SquadAvatar(
                              name: nickname,
                              avatar: user?.avatarUrl,
                              radius: 44,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            nickname,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '在小队里，收藏日常',
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _heading(
                  context,
                  '成就勋章',
                  () => _open(context, ProfileSettingsSection.achievements),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    key: const ValueKey('profile-achievements'),
                    onTap: () =>
                        _open(context, ProfileSettingsSection.achievements),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          const ProfileMedalPreview(),
                          const SizedBox(height: 12),
                          Text(
                            '为下一枚勋章留个位置',
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _heading(
                  context,
                  '小队封面',
                  () => _open(context, ProfileSettingsSection.squadCovers),
                ),
                const SizedBox(height: 8),
                squads.when(
                  loading: () => const SizedBox(
                    height: 144,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => Card(
                    child: ListTile(
                      title: const Text('小队封面暂未加载'),
                      trailing: TextButton(
                        onPressed: () =>
                            ref.invalidate(personalHomeSquadsProvider),
                        child: const Text('重试'),
                      ),
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(20),
                          leading: const Icon(Icons.panorama_outlined),
                          title: const Text('和小队一起，留下封面'),
                          subtitle: const Text('加入小队后在这里展示'),
                          onTap: () => _open(
                            context,
                            ProfileSettingsSection.squadCovers,
                          ),
                        ),
                      );
                    }
                    return SizedBox(
                      height: 174,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length,
                        padding: EdgeInsets.zero,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => SizedBox(
                          width: 230,
                          child: ProfileSquadCover(
                            squad: items[index],
                            compact: true,
                            onTap: () => _open(
                              context,
                              ProfileSettingsSection.squadCovers,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                _heading(
                  context,
                  '个人媒体资产',
                  () => _open(context, ProfileSettingsSection.media),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    key: const ValueKey('profile-media'),
                    onTap: () => _open(context, ProfileSettingsSection.media),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              for (final icon in [
                                Icons.image_outlined,
                                Icons.play_circle_outline_rounded,
                                Icons.style_outlined,
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: ExcludeSemantics(
                                      child: Icon(
                                        icon,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '你的照片、视频与故事',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 14,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '个人空间 · 仅自己可见',
                                  style: text.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _heading(BuildContext context, String title, VoidCallback onTap) =>
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: onTap, child: const Text('管理')),
        ],
      );
}
