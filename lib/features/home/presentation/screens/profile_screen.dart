import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    const useDemoBackend = bool.fromEnvironment(
      'USE_DEMO_BACKEND',
      defaultValue: true,
    );
    final demoState = useDemoBackend ? ref.watch(demoAppStoreProvider) : null;
    final user =
        ref.watch(authNotifierProvider).asData?.value ?? demoState?.currentUser;
    final themeMode = ref.watch(themeModeProvider);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final nickname = user?.nickname.trim().isNotEmpty == true
        ? user!.nickname.trim()
        : '朋友';
    final contact = user?.email ?? user?.phone;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colors.surfaceContainerHigh,
                      foregroundColor: colors.onSurface,
                      child: Text(
                        nickname.characters.first,
                        style: textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.headlineSmall,
                                ),
                              ),
                              if (user != null)
                                IconButton(
                                  tooltip: '编辑昵称',
                                  onPressed: () => _editNickname(nickname),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            contact ?? '和喜欢的人，分享正在发生的事',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                if (!useDemoBackend) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.manage_accounts_outlined),
                    title: const Text('账号与联系方式'),
                    subtitle: const Text('仅你自己可查看和管理'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/account/contacts'),
                  ),
                  const SizedBox(height: 12),
                ],
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
                const SizedBox(height: 34),
                Text('数据与隐私', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                const _InformationRow(
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
                const SizedBox(height: 34),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSigningOut ? null : _signOut,
                    icon: _isSigningOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: const Text('退出登录'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _selectTheme(ThemeMode mode) {
    ref.read(themeModeProvider.notifier).state = mode;
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

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('退出失败，请稍后再试')));
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
