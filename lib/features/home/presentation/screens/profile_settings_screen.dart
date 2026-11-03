import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers/conversation_cache_provider.dart';
import '../../../../app/providers/conversation_customization_providers.dart';
import '../../../../app/providers/current_user_provider.dart';
import '../../../../app/providers/diagnostics_provider.dart';
import '../../../../app/providers/offline_access_provider.dart';
import '../../../../app/providers/personal_home_providers.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/cloudbase_client_provider.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../shared/widgets/squad_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../squad/domain/entities/squad.dart';
import 'help_screen.dart';
import 'profile_showcase_widgets.dart';

enum ProfileSettingsSection {
  root,
  account,
  showcase,
  achievements,
  squadCovers,
  media,
  appearance,
  privacy,
}

void openProfileSettings(
  BuildContext context, {
  ProfileSettingsSection section = ProfileSettingsSection.root,
  VoidCallback? onOpenDataWorkshop,
  VoidCallback? onManageNotifications,
  VoidCallback? onManageRouteDevice,
  ValueChanged<Squad>? onManageSquad,
}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ProfileSettingsScreen(
        section: section,
        onOpenDataWorkshop: onOpenDataWorkshop,
        onManageNotifications: onManageNotifications,
        onManageRouteDevice: onManageRouteDevice,
        onManageSquad: onManageSquad,
      ),
    ),
  );
}

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({
    this.section = ProfileSettingsSection.root,
    this.onOpenDataWorkshop,
    this.onManageNotifications,
    this.onManageRouteDevice,
    this.onManageSquad,
    super.key,
  });
  final ProfileSettingsSection section;
  final VoidCallback? onOpenDataWorkshop,
      onManageNotifications,
      onManageRouteDevice;
  final ValueChanged<Squad>? onManageSquad;
  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends ConsumerState<ProfileSettingsScreen> {
  bool _isSigningOut = false, _isClearingRecords = false, _avatarBusy = false;
  void _open(ProfileSettingsSection section) => openProfileSettings(
    context,
    section: section,
    onOpenDataWorkshop: widget.onOpenDataWorkshop,
    onManageNotifications: widget.onManageNotifications,
    onManageRouteDevice: widget.onManageRouteDevice,
    onManageSquad: widget.onManageSquad,
  );
  ListTile _destination(
    String title,
    IconData icon,
    VoidCallback? onTap, {
    String? subtitle,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final useDemoBackend = ref.watch(useDemoBackendProvider);
    final nickname = user?.nickname.trim().isNotEmpty == true
        ? user!.nickname
        : '朋友';
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final themeMode = ref.watch(themeModeProvider);
    final diagnostics = ref.watch(diagnosticsProvider);
    final cache = ref.watch(conversationCacheProvider);
    final offlineAccess = ref.watch(offlineAccessProvider);
    final title = switch (widget.section) {
      ProfileSettingsSection.root => '设置',
      ProfileSettingsSection.account => '账号与资料',
      ProfileSettingsSection.showcase => '展示管理',
      ProfileSettingsSection.achievements => '成就勋章',
      ProfileSettingsSection.squadCovers => '小队封面',
      ProfileSettingsSection.media => '个人媒体资产',
      ProfileSettingsSection.appearance => '通知与外观',
      ProfileSettingsSection.privacy => '数据与隐私',
    };
    final content = <Widget>[];
    switch (widget.section) {
      case ProfileSettingsSection.root:
        content.addAll([
          _destination(
            '账号与资料',
            Icons.person_outline_rounded,
            () => _open(ProfileSettingsSection.account),
            subtitle: '头像、昵称与联系方式',
          ),
          _destination(
            '展示管理',
            Icons.dashboard_customize_outlined,
            () => _open(ProfileSettingsSection.showcase),
            subtitle: '勋章、小队封面与个人媒体',
          ),
          _destination(
            '通知与外观',
            Icons.tune_rounded,
            () => _open(ProfileSettingsSection.appearance),
          ),
          _destination(
            '数据与隐私',
            Icons.lock_outline_rounded,
            () => _open(ProfileSettingsSection.privacy),
          ),
          _destination(
            '使用帮助',
            Icons.help_outline_rounded,
            () => Navigator.of(
              context,
            ).push<void>(MaterialPageRoute(builder: (_) => const HelpScreen())),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: user == null || _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(_isSigningOut ? '正在退出登录…' : '退出登录'),
          ),
        ]);
      case ProfileSettingsSection.account:
        content.addAll([
          Center(
            child: SquadAvatar(
              name: nickname,
              avatar: user?.avatarUrl,
              radius: 48,
            ),
          ),
          const SizedBox(height: 16),
          _destination(
            '头像',
            Icons.account_circle_outlined,
            user == null ||
                    _avatarBusy ||
                    !ref.watch(personalAvatarAvailableProvider)
                ? null
                : _editAvatar,
            subtitle: ref.watch(personalAvatarAvailableProvider)
                ? '选择照片，预览后保存'
                : '此设备暂不支持选图',
          ),
          _destination(
            '昵称',
            Icons.edit_outlined,
            user == null ? null : () => _editNickname(nickname),
            subtitle: nickname,
          ),
          if (!useDemoBackend)
            _destination(
              '账号与联系方式',
              Icons.manage_accounts_outlined,
              () => context.push('/account/contacts'),
              subtitle: '仅你自己可查看和管理',
            ),
          if (_avatarBusy) const LinearProgressIndicator(),
        ]);
      case ProfileSettingsSection.showcase:
        content.addAll([
          _destination(
            '成就勋章',
            Icons.workspace_premium_outlined,
            () => _open(ProfileSettingsSection.achievements),
          ),
          _destination(
            '小队封面',
            Icons.panorama_outlined,
            () => _open(ProfileSettingsSection.squadCovers),
          ),
          _destination(
            '个人媒体资产',
            Icons.photo_library_outlined,
            () => _open(ProfileSettingsSection.media),
          ),
        ]);
      case ProfileSettingsSection.achievements:
        content.addAll([
          const SizedBox(height: 48),
          const ProfileMedalPreview(),
          const SizedBox(height: 24),
          Text(
            '勋章收集即将开放',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '为你和小队的共同瞬间，留一席展示的位置。',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ]);
      case ProfileSettingsSection.squadCovers:
        content.add(_covers());
      case ProfileSettingsSection.media:
        content.addAll([
          const SizedBox(height: 24),
          Icon(Icons.photo_library_outlined, size: 64, color: colors.primary),
          const SizedBox(height: 20),
          Text(
            '你的素材，先留给自己',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '选择素材并确认受众后，再分享给小队。',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          _destination(
            '私密素材空间',
            Icons.collections_outlined,
            widget.onOpenDataWorkshop,
            subtitle: '查看素材、编辑与准备分享',
          ),
          const SizedBox(height: 12),
          const Text('照片与视频资产展示位已预留', textAlign: TextAlign.center),
        ]);
      case ProfileSettingsSection.appearance:
        content.addAll([
          if (widget.onManageNotifications != null)
            _destination(
              '通知设置',
              Icons.notifications_outlined,
              widget.onManageNotifications,
              subtitle: '设备上的小队消息提醒',
            ),
          const SizedBox(height: 16),
          Text('外观', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ThemeChoice(
                label: '跟随系统',
                icon: Icons.brightness_auto_outlined,
                mode: ThemeMode.system,
                selected: themeMode == ThemeMode.system,
                onSelected: _selectTheme,
              ),
              _ThemeChoice(
                label: '浅色',
                icon: Icons.light_mode_outlined,
                mode: ThemeMode.light,
                selected: themeMode == ThemeMode.light,
                onSelected: _selectTheme,
              ),
              _ThemeChoice(
                label: '深色',
                icon: Icons.dark_mode_outlined,
                mode: ThemeMode.dark,
                selected: themeMode == ThemeMode.dark,
                onSelected: _selectTheme,
              ),
            ],
          ),
        ]);
      case ProfileSettingsSection.privacy:
        content.addAll([
          if (cache != null && user != null) ...[
            if (offlineAccess.status != OfflineAccessStatus.disabled)
              _destination(
                '本机聊天记录',
                Icons.offline_pin_outlined,
                () => context.push('/offline'),
              ),
            _destination(
              '清理本机聊天记录',
              Icons.cleaning_services_outlined,
              _isClearingRecords ? null : () => _clearRecords(user.id),
              subtitle: '保留服务器记录和未发送内容',
            ),
          ],
          if (widget.onManageRouteDevice != null)
            _destination(
              '路线设备',
              Icons.verified_user_outlined,
              widget.onManageRouteDevice,
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('发送错误报告'),
            subtitle: Text(
              diagnostics.error ??
                  (diagnostics.available
                      ? '仅发送脱敏错误信息，不含聊天、财务或健康内容'
                      : '此版本暂不可用'),
            ),
            value: diagnostics.enabled,
            onChanged: !diagnostics.available || diagnostics.saving
                ? null
                : (enabled) async {
                    if (enabled) {
                      final accepted = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('允许发送错误报告？'),
                          content: const Text(
                            '发送错误类别、应用版本和程序位置以帮助修复问题，不包含消息正文、个人资料、财务、健康或位置数据。你可以随时关闭。',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('同意并开启'),
                            ),
                          ],
                        ),
                      );
                      if (accepted != true || !mounted) return;
                    }
                    await ref
                        .read(diagnosticsProvider.notifier)
                        .setConsent(enabled);
                  },
          ),

          const SizedBox(height: 18),
          _InformationRow(
            icon: Icons.hub_outlined,
            title: useDemoBackend ? '当前为演示数据' : '数据来源',
            subtitle: useDemoBackend
                ? 'Apple 健康、小米运动健康、华为运动健康尚未连接。'
                : '外部健康数据来源将在连接后显示。',
          ),
          const Divider(height: 1),
          const _InformationRow(
            icon: Icons.lock_person_outlined,
            title: '分享范围由你决定',
            subtitle: '导入素材默认仅自己可见；发布时选择小队或指定成员。',
          ),
          const Divider(height: 1),
          const _InformationRow(
            icon: Icons.account_balance_wallet_outlined,
            title: '私密资产始终独立',
            subtitle: '个人私密资产不会进入分享素材或小队动态。',
          ),
        ]);
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _covers() => ref
      .watch(personalHomeSquadsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Column(
          children: [
            const Text('小队封面加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(personalHomeSquadsProvider),
              child: const Text('重试'),
            ),
          ],
        ),
        data: (squads) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (squads.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text('加入小队后，封面会出现在这里', textAlign: TextAlign.center),
              ),
            for (final squad in squads) ...[
              ProfileSquadCover(
                squad: squad,
                onTap: () => widget.onManageSquad?.call(squad),
              ),
              _destination(
                '管理小队资料',
                Icons.groups_outlined,
                widget.onManageSquad == null
                    ? null
                    : () => widget.onManageSquad!(squad),
              ),
              const SizedBox(height: 16),
            ],
            if (squads.isNotEmpty)
              const Text('封面沿用小队头像与名称', textAlign: TextAlign.center),
          ],
        ),
      );
  Future<void> _editAvatar() async {
    final owner = ref.read(currentUserProvider).asData?.value?.id;
    if (owner == null) return;
    setState(() => _avatarBusy = true);
    final result = await ref.read(squadAvatarPickerProvider).pick();
    if (!mounted) return;
    setState(() => _avatarBusy = false);
    if (ref.read(currentUserProvider).asData?.value?.id != owner) return;
    await result.match(
      (failure) async {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authFailureMessage(failure))));
      },
      (avatar) async {
        if (avatar == null) return;
        var saving = false;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('预览头像'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SquadAvatar(name: '', avatar: avatar, radius: 48),
                  const SizedBox(height: 16),
                  const Text('小队成员可见'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (ref.read(currentUserProvider).asData?.value?.id !=
                              owner) {
                            return;
                          }
                          setDialogState(() => saving = true);
                          final saved = await ref
                              .read(personalAvatarRepositoryProvider)
                              .save(avatar);
                          if (!mounted ||
                              !dialogContext.mounted ||
                              ref.read(currentUserProvider).asData?.value?.id !=
                                  owner) {
                            return;
                          }
                          await saved.match(
                            (failure) async {
                              setDialogState(() => saving = false);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(authFailureMessage(failure)),
                                ),
                              );
                            },
                            (_) async {
                              await ref
                                  .read(authNotifierProvider.notifier)
                                  .refreshCurrentUser();
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            },
                          );
                        },
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectTheme(ThemeMode mode) {
    unawaited(ref.read(themeModeProvider.notifier).select(mode));
  }

  Future<void> _editNickname(String currentNickname) async {
    var draft = currentNickname;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('编辑昵称'),
          content: TextFormField(
            initialValue: currentNickname,
            autofocus: true,
            maxLength: 60,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: '小队成员可见'),
            onChanged: (value) => draft = value,
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      final failure = await ref
                          .read(authNotifierProvider.notifier)
                          .updateNickname(draft);
                      if (!mounted || !dialogContext.mounted) return;
                      if (failure == null) {
                        Navigator.pop(dialogContext);
                      } else {
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(authFailureMessage(failure))),
                        );
                      }
                    },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearRecords(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理本机聊天记录？'),
        content: const Text('只清理此账号已下载的记录，不删除服务器记录或未发送内容。联网打开会话后会重新下载。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        ref.read(authNotifierProvider).asData?.value?.id != userId) {
      return;
    }
    setState(() => _isClearingRecords = true);
    var message = '本机聊天记录已清理';
    try {
      await ref.read(conversationCacheProvider)?.clearUser(userId);
    } catch (_) {
      message = '清理失败，请重试';
    }
    if (!mounted) return;
    setState(() => _isClearingRecords = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      final failure = await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) {
        if (failure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(switch (failure) {
                UnknownFailure(:final message) => message ?? '退出失败，请重试',
                _ => authFailureMessage(failure),
              }),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('退出失败，请稍后再试')));
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.icon,
    required this.mode,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final ThemeMode mode;
  final bool selected;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(mode),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
