// 仓库 hooks（.aetherlink/hooks.json）审阅/信任：入口卡片 + 工作区列表页 +
// 审阅弹层（内容变更时展示与已信任版本的行级差异）。
// 信任存储见 application/agent_hooks_trust.dart。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_runtime_access.dart';
import 'package:aetherlink_flutter/app/di/workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_hooks_trust.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/hooks/hook_meta.dart';

/// 仓库 hooks 入口（置顶）：有待审阅/内容变更的工作区时亮红提示。
class RepoHooksEntry extends ConsumerWidget {
  const RepoHooksEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workspaces = ref.watch(recentWorkspacesViewProvider);
    final trusted = ref.watch(agentHooksTrustProvider);
    var pending = 0;
    for (final ws in workspaces) {
      final raw = ref.watch(workspaceHooksFileProvider(ws.id)).value;
      if (raw != null && raw.trim().isNotEmpty && trusted[ws.id] != raw) {
        pending += 1;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pending > 0 ? theme.colorScheme.error : theme.dividerColor,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        leading: Icon(
          LucideIcons.folderGit2,
          size: 18,
          color: pending > 0
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: const Text('仓库 hooks（.aetherlink/hooks.json）'),
        subtitle: Text(
          pending > 0
              ? '$pending 个工作区的 hooks 待审阅或内容已变更'
              : '仓库携带的 hooks 需审阅并信任后才会执行',
          style: theme.textTheme.bodySmall?.copyWith(
            color: pending > 0
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(LucideIcons.chevronRight, size: 16),
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => const _RepoHooksPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
      ),
    );
  }
}

/// 仓库 hooks.json 审阅/信任页（工作区列表）。
class _RepoHooksPage extends ConsumerWidget {
  const _RepoHooksPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workspaces = ref.watch(recentWorkspacesViewProvider);
    final trusted = ref.watch(agentHooksTrustProvider);

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
        title: const Text('仓库 hooks'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            '工作区根目录的 .aetherlink/hooks.json 可随仓库共享 hooks 配置。'
            'hook 是任意命令，出于安全必须先审阅内容并信任后才会执行；'
            '文件内容一变，信任自动失效，需重新审阅。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (workspaces.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '还没有打开过工作区',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
                  for (var i = 0; i < workspaces.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 12, color: theme.dividerColor),
                    _WorkspaceHooksRow(
                      theme: theme,
                      workspaceId: workspaces[i].id,
                      workspaceName: workspaces[i].name,
                      trustedContent: trusted[workspaces[i].id],
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

class _WorkspaceHooksRow extends ConsumerWidget {
  const _WorkspaceHooksRow({
    required this.theme,
    required this.workspaceId,
    required this.workspaceName,
    required this.trustedContent,
  });

  final ThemeData theme;
  final String workspaceId;
  final String workspaceName;
  final String? trustedContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileAsync = ref.watch(workspaceHooksFileProvider(workspaceId));
    final raw = fileAsync.value;
    final loading = fileAsync.isLoading;
    final hasFile = raw != null && raw.trim().isNotEmpty;
    final config = hasFile ? decodeAgentHooksConfig(raw) : null;

    final (color, label) = switch ((loading, hasFile, trustedContent == raw)) {
      (true, _, _) => (theme.colorScheme.onSurfaceVariant, '读取中…'),
      (_, false, _) => (theme.colorScheme.onSurfaceVariant, '未配置'),
      (_, true, true) => (theme.colorScheme.tertiary, '已信任'),
      _ => (theme.colorScheme.error, trustedContent == null ? '待审阅' : '内容已变更'),
    };

    return ListTile(
      dense: true,
      title: Text(workspaceName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: hasFile
          ? Text(
              config == null
                  ? 'hooks.json 解析失败'
                  : '${config.hooks.length} 条 hook',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Container(
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
      ),
      onTap: hasFile ? () => _showReviewSheet(context, ref, raw) : null,
    );
  }

  /// 审阅弹层：内容已变更时先展示与已信任版本的行级差异；按条结构化
  /// 列出 hooks（http 型高亮外部 URL），原文可展开 + 信任/撤销。
  void _showReviewSheet(BuildContext context, WidgetRef ref, String raw) {
    final isTrusted = trustedContent == raw;
    final config = decodeAgentHooksConfig(raw);
    final diff = trustedContent != null && trustedContent != raw
        ? _diffLines(trustedContent!, raw)
        : null;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$workspaceName · hooks.json',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (diff != null) ...[
                        Text(
                          '与已信任版本的差异（重点审阅新增/修改行）：',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _DiffView(theme: theme, diff: diff),
                        const SizedBox(height: 10),
                      ],
                      if (config == null)
                        Text(
                          '解析失败：不是合法的 hooks.json（每条 hook 需带 '
                          'type: command / prompt / http）',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        )
                      else if (config.hooks.isEmpty)
                        Text(
                          '没有解析出任何有效 hook（缺 type 或缺对应载体的条目会被丢弃）',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        for (final hook in config.hooks) ...[
                          _RepoHookCard(theme: theme, hook: hook),
                          const SizedBox(height: 8),
                        ],
                      Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: Text(
                            '查看原文',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                raw,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (isTrusted)
                FilledButton.tonal(
                  onPressed: () {
                    ref
                        .read(agentHooksTrustProvider.notifier)
                        .revoke(workspaceId);
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('撤销信任'),
                )
              else
                FilledButton(
                  onPressed: () {
                    ref
                        .read(agentHooksTrustProvider.notifier)
                        .trust(workspaceId, raw);
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('信任并启用这些 hooks'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 行级 diff 项：' ' 未变 / '-' 删除 / '+' 新增。
typedef _DiffLine = (String tag, String line);

/// 简单 LCS 行级 diff（hooks.json 都很小，O(n·m) 足够）。
List<_DiffLine> _diffLines(String oldText, String newText) {
  final a = oldText.split('\n');
  final b = newText.split('\n');
  final lcs = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j]
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] > lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }
  final out = <_DiffLine>[];
  var i = 0, j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      out.add((' ', a[i]));
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      out.add(('-', a[i]));
      i++;
    } else {
      out.add(('+', b[j]));
      j++;
    }
  }
  while (i < a.length) {
    out.add(('-', a[i++]));
  }
  while (j < b.length) {
    out.add(('+', b[j++]));
  }
  return out;
}

/// diff 渲染：新增绿底、删除红底、未变灰字。
class _DiffView extends StatelessWidget {
  const _DiffView({required this.theme, required this.diff});

  final ThemeData theme;
  final List<_DiffLine> diff;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (tag, line) in diff)
            Container(
              color: switch (tag) {
                '+' => Colors.green.withValues(alpha: 0.15),
                '-' => Colors.red.withValues(alpha: 0.15),
                _ => null,
              },
              child: Text(
                '$tag $line',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.4,
                  color: switch (tag) {
                    '+' => Colors.green.shade800,
                    '-' => Colors.red.shade800,
                    _ => theme.colorScheme.onSurfaceVariant,
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 仓库 hooks 审阅里的单条 hook 卡片：类型徽标 + 事件/匹配 + 载体（http URL 高亮）。
class _RepoHookCard extends StatelessWidget {
  const _RepoHookCard({required this.theme, required this.hook});

  final ThemeData theme;
  final AgentHook hook;

  @override
  Widget build(BuildContext context) {
    final scopeParts = [
      if (hook.matcher != '*') 'matcher: ${hook.matcher}',
      if (hook.pattern != '*') 'pattern: ${hook.pattern}',
      if (hook.timeoutSeconds != kAgentHookDefaultTimeoutSeconds)
        '超时 ${hook.timeoutSeconds}s',
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HookTypeBadge(type: hook.type),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hook.event.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hook.payload,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.4,
              // http 型高亮外部 URL：这是审阅的安全重点（数据会 POST 出去）。
              color: hook.type == AgentHookType.http
                  ? theme.colorScheme.error
                  : null,
              fontWeight: hook.type == AgentHookType.http
                  ? FontWeight.w600
                  : null,
            ),
          ),
          if (hook.type == AgentHookType.http && hook.headers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '自定义 headers：${hook.headers.keys.join('、')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (scopeParts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              scopeParts.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
