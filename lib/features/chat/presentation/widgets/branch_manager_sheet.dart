import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/message_ordering.dart';

/// Opens the 分支管理 sheet — the lightweight (list) form of Cherry Studio's
/// TopicMessageFlow canvas: the whole message tree as an indented tree, with the
/// current path highlighted and off-path branches dimmed (已禁用), plus the same
/// `{branchCount} 分支 · {nodeCount} 节点` stats. Tapping a node makes it the
/// active leaf ([ChatController.switchToBranch]) so the conversation jumps to
/// that branch. The visual node-graph (pan/zoom/minimap) is deferred.
Future<void> showBranchManagerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => const _BranchManagerSheet(),
  );
}

/// One node row in the branch tree (a [Message] plus its tree placement flags).
class BranchTreeRow {
  const BranchTreeRow({
    required this.message,
    required this.depth,
    required this.isActive,
    required this.isOnActivePath,
    required this.isInactiveBranch,
  });

  final Message message;

  /// Indentation depth (top-level turn = 0).
  final int depth;

  /// The single active leaf the conversation continues from.
  final bool isActive;

  /// On the active path (active leaf → root).
  final bool isOnActivePath;

  /// An off-path (已禁用) branch node.
  final bool isInactiveBranch;
}

/// The built branch tree: DFS-ordered [rows] + Cherry-style stats.
class BranchTree {
  const BranchTree({
    required this.rows,
    required this.nodeCount,
    required this.branchCount,
  });

  final List<BranchTreeRow> rows;
  final int nodeCount;
  final int branchCount;

  static const empty = BranchTree(rows: [], nodeCount: 0, branchCount: 0);
}

/// Pure builder for the 分支管理 tree from a topic's flat [messages] (root
/// excluded). DFS pre-order, children chronologically ordered; marks the active
/// path from [activeNodeId] up to [rootId]. `branchCount` ports Cherry's
/// `countBranchPaths` — the leaf count when there's more than one leaf, else 0
/// (a linear chat shows 0 分支). Defensive against orphans (parent missing) and
/// cycles.
BranchTree buildBranchTree(
  List<Message> messages, {
  required String? rootId,
  required String? activeNodeId,
}) {
  if (messages.isEmpty) return BranchTree.empty;
  final byId = {for (final m in messages) m.id: m};

  final childrenByParent = <String, List<Message>>{};
  for (final m in messages) {
    (childrenByParent[m.parentId ?? ''] ??= <Message>[]).add(m);
  }
  for (final list in childrenByParent.values) {
    list.sort(compareMessagesChronologically);
  }

  // Top-level nodes: children of the virtual root, plus any orphan whose parent
  // is missing (defensive — a healthy tree has none).
  bool isTopLevel(Message m) =>
      m.parentId == null ||
      m.parentId == rootId ||
      !byId.containsKey(m.parentId);
  final roots = messages.where(isTopLevel).toList()
    ..sort(compareMessagesChronologically);

  // Active path: from the active leaf up to (not including) the root.
  final activePath = <String>{};
  var cur = activeNodeId;
  while (cur != null &&
      cur != rootId &&
      byId.containsKey(cur) &&
      activePath.add(cur)) {
    cur = byId[cur]!.parentId;
  }
  final hasActive = activePath.isNotEmpty;

  final rows = <BranchTreeRow>[];
  final visited = <String>{};
  void dfs(Message m, int depth) {
    if (!visited.add(m.id)) return; // cycle guard
    rows.add(
      BranchTreeRow(
        message: m,
        depth: depth,
        isActive: m.id == activeNodeId,
        isOnActivePath: activePath.contains(m.id),
        isInactiveBranch: hasActive && !activePath.contains(m.id),
      ),
    );
    for (final c in childrenByParent[m.id] ?? const <Message>[]) {
      dfs(c, depth + 1);
    }
  }

  for (final r in roots) {
    dfs(r, 0);
  }

  final parentIds = {
    for (final m in messages)
      if (m.parentId != null) m.parentId!,
  };
  final leafCount = messages.where((m) => !parentIds.contains(m.id)).length;
  return BranchTree(
    rows: rows,
    nodeCount: messages.length,
    branchCount: leafCount > 1 ? leafCount : 0,
  );
}

/// The tree plus a per-message content preview (loaded from blocks).
typedef _BranchData = ({BranchTree tree, Map<String, String> previews});

class _BranchManagerSheet extends ConsumerStatefulWidget {
  const _BranchManagerSheet();

  @override
  ConsumerState<_BranchManagerSheet> createState() =>
      _BranchManagerSheetState();
}

class _BranchManagerSheetState extends ConsumerState<_BranchManagerSheet> {
  late final Future<_BranchData> _future = _load();

  Future<_BranchData> _load() async {
    final topic = await ref.read(currentTopicProvider.future);
    if (topic == null) {
      return (tree: BranchTree.empty, previews: const <String, String>{});
    }
    final repo = ref.read(chatRepositoryProvider);
    final messages = await repo.getMessagesByTopicId(topic.id);
    if (messages.isEmpty) {
      return (tree: BranchTree.empty, previews: const <String, String>{});
    }
    final rootId = await repo.getRootMessageId(topic.id);

    // Bulk-load blocks once for a short content preview per node.
    final blockIds = [for (final m in messages) ...m.blocks];
    final blocks = await repo.getMessageBlocksByIds(blockIds);
    final blockById = {for (final b in blocks) b.id: b};
    final previews = <String, String>{};
    for (final m in messages) {
      for (final id in m.blocks) {
        final b = blockById[id];
        if (b is MainTextBlock && b.content.trim().isNotEmpty) {
          final t = b.content.trim().replaceAll(RegExp(r'\s+'), ' ');
          previews[m.id] = t.length > 60 ? '${t.substring(0, 60)}…' : t;
          break;
        }
      }
    }

    final tree = buildBranchTree(
      messages,
      rootId: rootId,
      activeNodeId: topic.activeNodeId,
    );
    return (tree: tree, previews: previews);
  }

  Future<void> _onTap(BranchTreeRow row) async {
    if (!row.isActive) {
      await ref
          .read(chatControllerProvider.notifier)
          .switchToBranch(row.message.id);
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.8),
        child: FutureBuilder<_BranchData>(
          future: _future,
          builder: (context, snapshot) {
            final tree = snapshot.data?.tree ?? BranchTree.empty;
            final previews =
                snapshot.data?.previews ?? const <String, String>{};
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(theme, tree),
                _legend(theme),
                const Divider(height: 1),
                Flexible(
                  child: !snapshot.hasData
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : tree.rows.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              '当前话题暂无消息',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: tree.rows.length,
                          itemBuilder: (_, i) => _BranchRowTile(
                            row: tree.rows[i],
                            preview: previews[tree.rows[i].message.id] ?? '',
                            onTap: () => _onTap(tree.rows[i]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, BranchTree tree) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Icon(LucideIcons.gitBranch, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '分支管理',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${tree.branchCount} 分支 · ${tree.nodeCount} 节点',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          _legendItem(theme, _kUserColor, '用户'),
          _legendItem(theme, _kAssistantColor, '助手'),
          _legendDash(theme, theme.colorScheme.primary, '当前', dashed: false),
          _legendDash(
            theme,
            theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            '已禁用',
            dashed: true,
          ),
        ],
      ),
    );
  }

  Widget _legendItem(ThemeData theme, Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: theme.textTheme.labelSmall),
    ],
  );

  Widget _legendDash(
    ThemeData theme,
    Color color,
    String label, {
    required bool dashed,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(dashed ? Icons.more_horiz : Icons.remove, size: 16, color: color),
      const SizedBox(width: 4),
      Text(label, style: theme.textTheme.labelSmall),
    ],
  );
}

const Color _kUserColor = Color(0xFF22C55E); // green-500 — 用户
const Color _kAssistantColor = Color(0xFF3B82F6); // blue-500 — 助手

/// A single indented node row: role tag + model + preview + status/time, with
/// current-branch highlight and 已禁用 dimming.
class _BranchRowTile extends StatelessWidget {
  const _BranchRowTile({
    required this.row,
    required this.preview,
    required this.onTap,
  });

  final BranchTreeRow row;
  final String preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = row.message;
    final isUser = m.role == MessageRole.user;
    final roleColor = isUser ? _kUserColor : _kAssistantColor;

    return Opacity(
      opacity: row.isInactiveBranch ? 0.55 : 1,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.0 + row.depth * 16, 2, 12, 2),
        child: Material(
          color: row.isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.10)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: row.isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: row.isActive ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: roleColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _roleLabel(m.role),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (m.model?.name != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            m.model!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (row.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '当前',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _fmtTime(m.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _roleLabel(MessageRole role) => switch (role) {
    MessageRole.user => '用户',
    MessageRole.assistant => '助手',
    MessageRole.system => '系统',
    MessageRole.root => '根',
  };

  static String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}
