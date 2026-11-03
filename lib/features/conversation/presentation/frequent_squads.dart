import 'package:flutter/material.dart';

import '../../../shared/widgets/squad_avatar.dart';
import '../../squad/domain/entities/squad.dart';
import '../domain/conversation_preference.dart';

final class FrequentSquads extends StatelessWidget {
  const FrequentSquads({
    required this.squads,
    required this.preferences,
    required this.onOpen,
    super.key,
  });
  final List<Squad> squads;
  final Map<String, ConversationPreference> preferences;
  final ValueChanged<Squad> onOpen;
  @override
  Widget build(BuildContext context) {
    final frequent =
        squads.where((s) {
          final p = preferences[s.id];
          return p != null && (p.isPinned || p.recentOpenCount > 0);
        }).toList()..sort(
          (a, b) => compareFrequentConversations(
            preferences[a.id]!,
            preferences[b.id]!,
          ),
        );
    if (frequent.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 100,
      child: ListView.separated(
        key: const ValueKey('frequent-squads'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: frequent.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final squad = frequent[index];
          final pref = preferences[squad.id]!;
          final label = pref.displayName(squad.name);
          return SizedBox(
            width: 64,
            child: InkWell(
              key: ValueKey('frequent-${squad.id}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => onOpen(squad),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SquadAvatar(name: squad.name, avatar: squad.avatarUrl),
                      if (pref.isPinned)
                        Positioned(
                          right: -4,
                          bottom: -2,
                          child: Icon(
                            Icons.push_pin_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
