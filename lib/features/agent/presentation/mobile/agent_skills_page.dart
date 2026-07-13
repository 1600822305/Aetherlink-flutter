// 智能体技能页（设计初稿 §决策 30 第一步）：顶栏三点菜单 →「技能」。
// 底层复用 settings 的技能库（经 app/di/skills_access seam），UI 面向
// 智能体单独设计：列表 + 启用开关 + 详情抽屉（正文即 read_skill 读到的
// 内容）。编辑/新建走既有技能编辑器路由。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/skills_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

Future<void> showAgentSkillsPage(BuildContext context) {
  // 零时长路由：MaterialPageRoute 即使去掉视觉动画仍保留 300ms
  // transitionDuration（见 app_router._instant 的说明），进入/返回都会卡一拍。
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const AgentSkillsPage(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class AgentSkillsPage extends ConsumerStatefulWidget {
  const AgentSkillsPage({super.key});

  @override
  ConsumerState<AgentSkillsPage> createState() => _AgentSkillsPageState();
}

class _AgentSkillsPageState extends ConsumerState<AgentSkillsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Skill> _filter(List<Skill> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.description.toLowerCase().contains(q) ||
              s.tags.any((t) => t.toLowerCase().contains(q)),
        )
        .toList();
  }

  Future<void> _toggle(Skill skill, bool enabled) async {
    final ok = await ref
        .read(skillsProvider.notifier)
        .toggle(skill.id, enabled: enabled);
    if (!ok && mounted) {
      AppToast.info(context, '最多同时启用 $kMaxEnabledSkills 个技能');
    }
  }

  Future<void> _create() async {
    final skill = await ref.read(skillsProvider.notifier).create();
    if (!mounted) return;
    context.push(AppRouter.skillEditorPath(skill.id));
  }

  void _showDetail(Skill skill) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SkillDetailSheet(skillId: skill.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final all = ref.watch(skillsProvider).value ?? const <Skill>[];
    final builtin = _filter(
      all.where((s) => s.source == SkillSource.builtin).toList(),
    );
    final custom = _filter(
      all.where((s) => s.source != SkillSource.builtin).toList(),
    );
    final enabledCount = all.where((s) => s.enabled).length;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        title: const Text(
          '技能',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            tooltip: '新建技能',
            icon: const Icon(LucideIcons.plus, size: 20),
            onPressed: _create,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索技能...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '启用的技能会列入智能体系统提示，模型按需 read_skill 读取正文',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '$enabledCount 已启用',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: builtin.isEmpty && custom.isEmpty
                ? Center(
                    child: Text(
                      _query.trim().isEmpty ? '技能库为空' : '没有找到匹配的技能',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomPad),
                    children: [
                      if (custom.isNotEmpty) ...[
                        _sectionLabel(theme, '自定义'),
                        for (final s in custom) _row(theme, s),
                      ],
                      if (builtin.isNotEmpty) ...[
                        _sectionLabel(theme, '内置'),
                        for (final s in builtin) _row(theme, s),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, Skill skill) {
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _showDetail(skill),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                Text(
                  skill.emoji ?? '🔧',
                  style: const TextStyle(fontSize: 19, height: 1),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        skill.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: skill.enabled,
                  onChanged: (v) => _toggle(skill, v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 技能详情抽屉：元信息 + SKILL.md 正文（即 read_skill 返回的内容）。
/// watch 技能库，编辑器改完回来即时刷新。
class _SkillDetailSheet extends ConsumerWidget {
  const _SkillDetailSheet({required this.skillId});

  final String skillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final skill = (ref.watch(skillsProvider).value ?? const <Skill>[])
        .where((s) => s.id == skillId)
        .firstOrNull;
    if (skill == null) return const SizedBox.shrink();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Text(
                    skill.emoji ?? '🔧',
                    style: const TextStyle(fontSize: 22, height: 1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      skill.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(AppRouter.skillEditorPath(skill.id));
                    },
                    icon: const Icon(LucideIcons.pencil, size: 14),
                    label: const Text('编辑'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  skill.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: skill.content.trim().isEmpty
                  ? Center(
                      child: Text(
                        '没有正文（read_skill 只会返回描述）',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        skill.content,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
