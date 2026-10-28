import 'package:flutter/material.dart';

enum ConversationActivityFilter { all, withMessages, withoutMessages }

bool matchesConversationActivity(
  ConversationActivityFilter filter,
  bool hasMessages,
) => switch (filter) {
  ConversationActivityFilter.all => true,
  ConversationActivityFilter.withMessages => hasMessages,
  ConversationActivityFilter.withoutMessages => !hasMessages,
};

bool matchesConversationSearch({
  required String query,
  required String squadName,
  required String preview,
}) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return squadName.toLowerCase().contains(normalized) ||
      preview.toLowerCase().contains(normalized);
}

final class ConversationListControls extends StatelessWidget {
  const ConversationListControls({
    required this.controller,
    required this.query,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
    super.key,
  });

  final TextEditingController controller;
  final String query;
  final ConversationActivityFilter filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ConversationActivityFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('会话', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('conversation-search-field'),
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: '搜索小队或消息',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除搜索',
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final option in ConversationActivityFilter.values)
                ChoiceChip(
                  label: Text(_labelFor(option)),
                  selected: filter == option,
                  onSelected: (_) => onFilterChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _labelFor(ConversationActivityFilter value) => switch (value) {
    ConversationActivityFilter.all => '全部',
    ConversationActivityFilter.withMessages => '有消息',
    ConversationActivityFilter.withoutMessages => '暂无消息',
  };
}

final class ConversationListNoResults extends StatelessWidget {
  const ConversationListNoResults({required this.onReset, super.key});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('没有找到匹配的会话', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextButton(onPressed: onReset, child: const Text('清除搜索和筛选')),
        ],
      ),
    );
  }
}
