import 'package:flutter/material.dart';

import '../../../../shared/widgets/squad_avatar.dart';
import '../../../squad/domain/entities/squad.dart';

/// A cover composed from the Squad's existing shared identity.
class ProfileSquadCover extends StatelessWidget {
  const ProfileSquadCover({
    required this.squad,
    required this.onTap,
    this.compact = false,
    super.key,
  });
  final Squad squad;
  final VoidCallback onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 144 : 172),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.secondaryContainer, colors.surfaceContainerLow],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SquadAvatar(
                    name: squad.name,
                    avatar: squad.avatarUrl,
                    radius: 24,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.north_east_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                squad.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (!compact && squad.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    squad.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileMedalPreview extends StatelessWidget {
  const ProfileMedalPreview({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final icon in [
          Icons.workspace_premium_outlined,
          Icons.auto_awesome_outlined,
          Icons.explore_outlined,
        ])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              width: 60,
              height: 68,
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 30,
                  color: colors.onSurfaceVariant.withValues(alpha: .45),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
