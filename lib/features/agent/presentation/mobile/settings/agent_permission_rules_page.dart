// 「权限规则」设置页（工作区管理 → 权限规则）。
//
// 查看/删除智能体审批的用户全局权限规则（审批卡「总是允许 …」「总是
// 禁止 …」落下的持久化条目）。规则模型见 domain/permission_rule.dart，
// 存储见 application/agent_permission_rules.dart。工作区级规则放在
// 各工作区根目录的 `.aetherlink/permissions.json`（同格式，可随仓库
// 提交共享），这里只做说明不代管。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_permission_rules.dart';
import 'package:aetherlink_flutter/features/agent/domain/permission_rule.dart';

/// 打开权限规则设置页。
Future<void> showAgentPermissionRulesPage(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const AgentPermissionRulesPage(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class AgentPermissionRulesPage extends ConsumerWidget {
  const AgentPermissionRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rules = ref.watch(agentPermissionRulesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('权限规则'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _HintCard(
            theme: theme,
            text: '审批卡上选「总是允许 …」「总是禁止 …」会在这里落成持久规则：'
                '允许的命令下次免审批，禁止的直接拦截。规则按 权限域 + 匹配模式 '
                '判定（如 terminal_execute + npm run *），后写的规则优先。'
                '越出项目工作区目录的终端命令无论如何设置都会要求确认。\n'
                '项目级规则可放在工作区根目录 .aetherlink/permissions.json'
                '（同格式 JSON，可随仓库提交共享）。',
          ),
          const SizedBox(height: 12),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '还没有持久规则\n在审批卡上选「总是允许 / 总是禁止」即可添加',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < rules.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 12,
                        color: theme.dividerColor,
                      ),
                    _RuleRow(
                      theme: theme,
                      rule: rules[i],
                      onDelete: () => ref
                          .read(agentPermissionRulesProvider.notifier)
                          .removeAt(i),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.theme,
    required this.rule,
    required this.onDelete,
  });

  final ThemeData theme;
  final PermissionRule rule;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          _ActionBadge(theme: theme, action: rule.action),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.pattern,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  rule.permission,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              LucideIcons.trash2,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.theme, required this.action});

  final ThemeData theme;
  final PermissionAction action;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (action) {
      PermissionAction.allow => (theme.colorScheme.tertiary, '允许'),
      PermissionAction.ask => (theme.colorScheme.primary, '询问'),
      PermissionAction.deny => (theme.colorScheme.error, '禁止'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.theme, required this.text});

  final ThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.info,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
