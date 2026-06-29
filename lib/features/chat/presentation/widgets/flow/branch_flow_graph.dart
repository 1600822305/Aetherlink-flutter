import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/message_ordering.dart';

/// The styling state of an edge between two nodes — a 1:1 port of Cherry
/// Studio's `TopicMessageFlowEdgeState`.
enum BranchFlowEdgeState {
  /// On the current (active) path — green solid-feel line.
  active,

  /// A plain parent→child link with no special meaning.
  normal,

  /// Off the active path (已禁用) — dimmed.
  inactive,

  /// One of several assistant siblings under the same parent (a fork).
  sibling,
}

/// One node in the branch flow graph (a [Message] plus its placement flags),
/// porting Cherry's `TopicMessageFlowNodeData`.
class BranchFlowNode {
  const BranchFlowNode({
    required this.message,
    required this.parentId,
    required this.isActive,
    required this.isOnActivePath,
    required this.isInactiveBranch,
    required this.isSiblingBranch,
  });

  final Message message;

  String get id => message.id;

  /// The parent node id, or null when this is a graph root (its real parent is
  /// the unrendered virtual root).
  final String? parentId;

  /// The single active leaf the conversation continues from.
  final bool isActive;

  /// On the active path (active node → root).
  final bool isOnActivePath;

  /// An off-path (已禁用) node — only when there is an active path at all.
  final bool isInactiveBranch;

  /// An assistant node sharing its parent with other assistant siblings
  /// (a multi-model / regenerate fork).
  final bool isSiblingBranch;
}

/// One parent→child edge, carrying its resolved [state].
class BranchFlowEdge {
  const BranchFlowEdge({
    required this.source,
    required this.target,
    required this.state,
  });

  final String source;
  final String target;
  final BranchFlowEdgeState state;
}

/// Cherry's `{nodeCount, branchCount, activePathLength}` stats.
class BranchFlowStats {
  const BranchFlowStats({
    required this.nodeCount,
    required this.branchCount,
    required this.activePathLength,
  });

  final int nodeCount;
  final int branchCount;
  final int activePathLength;

  static const empty =
      BranchFlowStats(nodeCount: 0, branchCount: 0, activePathLength: 0);
}

/// The built graph: nodes + edges + stats + the active node id.
class BranchFlowGraph {
  const BranchFlowGraph({
    required this.nodes,
    required this.edges,
    required this.activeNodeId,
    required this.stats,
  });

  final List<BranchFlowNode> nodes;
  final List<BranchFlowEdge> edges;
  final String? activeNodeId;
  final BranchFlowStats stats;

  static const empty = BranchFlowGraph(
    nodes: [],
    edges: [],
    activeNodeId: null,
    stats: BranchFlowStats.empty,
  );
}

/// Pure builder for the 分支管理 graph from a topic's flat [messages] (the
/// virtual root excluded). 1:1 port of Cherry's `buildTopicMessageFlowGraph`:
/// resolves the active path from [activeNodeId] up to [rootId], marks
/// active/on-path/inactive/sibling flags, and counts branches (`countBranchPaths`
/// — leaf count when >1, else 0). Defensive against missing parents and cycles.
BranchFlowGraph buildBranchFlowGraph(
  List<Message> messages, {
  required String? rootId,
  required String? activeNodeId,
}) {
  if (messages.isEmpty) return BranchFlowGraph.empty;

  final byId = {for (final m in messages) m.id: m};

  // A node is a graph root when its parent is the (unrendered) virtual root or
  // missing entirely — its edge to that parent is never drawn.
  String? renderedParent(Message m) {
    final p = m.parentId;
    if (p == null || p == rootId || !byId.containsKey(p)) return null;
    return p;
  }

  // Active path: from the active node up to (not including) the root.
  final activePath = <String>{};
  var cur = activeNodeId;
  while (cur != null &&
      cur != rootId &&
      byId.containsKey(cur) &&
      activePath.add(cur)) {
    cur = byId[cur]!.parentId;
  }
  final hasActivePath = activePath.isNotEmpty;

  // Assistant fork detection: a parent with more than one assistant child marks
  // all of those assistant children as sibling branches.
  final assistantChildCount = <String, int>{};
  for (final m in messages) {
    final p = renderedParent(m) ?? m.parentId;
    if (m.role == MessageRole.assistant && p != null) {
      assistantChildCount[p] = (assistantChildCount[p] ?? 0) + 1;
    }
  }
  bool isSiblingBranch(Message m) {
    final p = renderedParent(m) ?? m.parentId;
    return m.role == MessageRole.assistant &&
        p != null &&
        (assistantChildCount[p] ?? 0) > 1;
  }

  final nodes = [
    for (final m in messages)
      BranchFlowNode(
        message: m,
        parentId: renderedParent(m),
        isActive: m.id == activeNodeId,
        isOnActivePath: activePath.contains(m.id),
        isInactiveBranch: hasActivePath && !activePath.contains(m.id),
        isSiblingBranch: isSiblingBranch(m),
      ),
  ];

  final edges = <BranchFlowEdge>[];
  for (final n in nodes) {
    final p = n.parentId;
    if (p == null) continue;
    final BranchFlowEdgeState state;
    if (activePath.contains(p) && activePath.contains(n.id)) {
      state = BranchFlowEdgeState.active;
    } else if (hasActivePath && !activePath.contains(n.id)) {
      state = BranchFlowEdgeState.inactive;
    } else if (n.isSiblingBranch) {
      state = BranchFlowEdgeState.sibling;
    } else {
      state = BranchFlowEdgeState.normal;
    }
    edges.add(BranchFlowEdge(source: p, target: n.id, state: state));
  }

  // branchCount = leaf count when more than one leaf, else 0 (linear = 0 分支).
  final parentIds = {
    for (final m in messages)
      if (m.parentId != null) m.parentId!,
  };
  final leafCount = messages.where((m) => !parentIds.contains(m.id)).length;

  return BranchFlowGraph(
    nodes: nodes,
    edges: edges,
    activeNodeId: activeNodeId,
    stats: BranchFlowStats(
      nodeCount: nodes.length,
      branchCount: leafCount > 1 ? leafCount : 0,
      activePathLength: activePath.length,
    ),
  );
}

/// Chronological child ordering used by both the graph and the layout, so the
/// two never disagree on sibling order.
int compareBranchNodes(BranchFlowNode a, BranchFlowNode b) =>
    compareMessagesChronologically(a.message, b.message);
