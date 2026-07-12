// 智能体 tab：档案列表 + 新建入口（参考聊天侧边栏助手 tab 架构）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';

class AgentProfileTab extends ConsumerWidget {
  const AgentProfileTab({required this.onGoToTopics, super.key});

  /// 选中智能体后切到「话题」tab（与聊天侧边栏选助手后跳话题一致）。
  final VoidCallback onGoToTopics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profiles = ref.watch(agentProfilesProvider);
    final selectedId = ref.watch(selectedAgentProfileIdProvider);
    final tasks = ref.watch(agentTasksProvider);
    final counts = <String, int>{};
    for (final t in tasks) {
      counts[t.profileId] = (counts[t.profileId] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final p in profiles)
                _ProfileItem(
                  profile: p,
                  selected: p.id == selectedId,
                  topicCount: counts[p.id] ?? 0,
                  onSelect: () {
                    ref
                        .read(selectedAgentProfileIdProvider.notifier)
                        .select(p.id);
                    ref.read(selectedAgentTaskIdProvider.notifier).select(null);
                    onGoToTopics();
                  },
                ),
              _NewProfileRow(onTap: () {}), // TODO(agent): 新建/编辑智能体页
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '共 ${profiles.length} 个智能体',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.profile,
    required this.selected,
    required this.topicCount,
    required this.onSelect,
  });

  final AgentProfile profile;
  final bool selected;
  final int topicCount;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? cs.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: selected
                      ? cs.primary.withValues(alpha: 0.15)
                      : cs.onSurface.withValues(alpha: 0.06),
                  child: Text(
                    profile.emoji,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      Text(
                        '$topicCount 个话题${profile.builtin ? ' · 内置' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(LucideIcons.check, size: 16, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewProfileRow extends StatelessWidget {
  const _NewProfileRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(LucideIcons.plus, size: 18, color: muted),
                const SizedBox(width: 10),
                Text(
                  '新建智能体',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
