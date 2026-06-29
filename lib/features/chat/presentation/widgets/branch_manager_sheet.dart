import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/flow/branch_flow_canvas.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/flow/branch_flow_graph.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/flow/branch_flow_layout.dart';

/// Opens the 分支管理 sheet — the full node-graph form of Cherry Studio's
/// TopicMessageFlow canvas: the whole message tree drawn as pan/zoom-able node
/// cards joined by state-colored edges (绿=当前路径 / 灰虚线=已禁用 / 兄弟分支),
/// with a minimap, zoom controls and a legend, plus `{branchCount} 分支 ·
/// {nodeCount} 节点` stats. Tapping a node makes it the active leaf
/// ([ChatController.switchToBranch]) so the conversation jumps to that branch.
Future<void> showBranchManagerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => const _BranchManagerSheet(),
  );
}

/// The laid-out graph plus a per-message content preview (loaded from blocks).
typedef _BranchData = ({BranchFlowLayout layout, Map<String, String> previews});

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
      return (layout: BranchFlowLayout.empty, previews: const <String, String>{});
    }
    final repo = ref.read(chatRepositoryProvider);
    final messages = await repo.getMessagesByTopicId(topic.id);
    if (messages.isEmpty) {
      return (layout: BranchFlowLayout.empty, previews: const <String, String>{});
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
          previews[m.id] = t.length > 80 ? '${t.substring(0, 80)}…' : t;
          break;
        }
      }
    }

    final graph = buildBranchFlowGraph(
      messages,
      rootId: rootId,
      activeNodeId: topic.activeNodeId,
    );
    return (layout: layoutBranchFlowGraph(graph), previews: previews);
  }

  Future<void> _onNodeTap(BranchFlowNode node) async {
    if (!node.isActive) {
      await ref
          .read(chatControllerProvider.notifier)
          .switchToBranch(node.message.id);
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    return SafeArea(
      child: SizedBox(
        height: mq.size.height * 0.85,
        child: FutureBuilder<_BranchData>(
          future: _future,
          builder: (context, snapshot) {
            final layout = snapshot.data?.layout ?? BranchFlowLayout.empty;
            final previews = snapshot.data?.previews ?? const <String, String>{};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(theme, layout.stats),
                const Divider(height: 1),
                Expanded(
                  child: !snapshot.hasData
                      ? const Center(child: CircularProgressIndicator())
                      : layout.placed.isEmpty
                          ? Center(
                              child: Text(
                                '当前话题暂无消息',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : BranchFlowCanvas(
                              layout: layout,
                              previews: previews,
                              onNodeTap: _onNodeTap,
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, BranchFlowStats stats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
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
            '${stats.branchCount} 分支 · ${stats.nodeCount} 节点',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
