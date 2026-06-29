import 'dart:ui';

import 'branch_flow_graph.dart';

/// Card size + spacing, mirroring Cherry's `TOPIC_MESSAGE_FLOW_NODE_SIZE` /
/// `GRAPH_SPACING` (scaled a little narrower for phone screens).
const double kBranchNodeWidth = 200;
const double kBranchNodeHeight = 108;
const double kBranchNodeSep = 40; // horizontal gap between siblings
const double kBranchRankSep = 72; // vertical gap between depths
const double kBranchMargin = 32; // outer padding around the whole tree

/// A node positioned on the canvas (top-left [offset]).
class BranchFlowPlacedNode {
  const BranchFlowPlacedNode({required this.node, required this.offset});

  final BranchFlowNode node;
  final Offset offset;

  Rect get rect =>
      Rect.fromLTWH(offset.dx, offset.dy, kBranchNodeWidth, kBranchNodeHeight);
  Offset get topCenter => Offset(offset.dx + kBranchNodeWidth / 2, offset.dy);
  Offset get bottomCenter =>
      Offset(offset.dx + kBranchNodeWidth / 2, offset.dy + kBranchNodeHeight);
  Offset get center => Offset(
        offset.dx + kBranchNodeWidth / 2,
        offset.dy + kBranchNodeHeight / 2,
      );
}

/// The laid-out graph: placed nodes + edges + the bounding [size] of the whole
/// tree (used to size the scrollable canvas).
class BranchFlowLayout {
  const BranchFlowLayout({
    required this.placed,
    required this.edges,
    required this.size,
    required this.activeNodeId,
    required this.stats,
  });

  final List<BranchFlowPlacedNode> placed;
  final List<BranchFlowEdge> edges;
  final Size size;
  final String? activeNodeId;
  final BranchFlowStats stats;

  BranchFlowPlacedNode? byId(String id) {
    for (final p in placed) {
      if (p.node.id == id) return p;
    }
    return null;
  }

  static const empty = BranchFlowLayout(
    placed: [],
    edges: [],
    size: Size.zero,
    activeNodeId: null,
    stats: BranchFlowStats.empty,
  );
}

/// Assigns top-down (TB) tree coordinates to [graph]. A tidy layout: each leaf
/// takes the next column, every parent is centered over its children, and each
/// subtree owns a contiguous column range so siblings never overlap. Replaces
/// Cherry's dagre dependency with a self-contained walk (the data is a tree, so
/// a leaf-packing layout is sufficient and deterministic).
BranchFlowLayout layoutBranchFlowGraph(BranchFlowGraph graph) {
  if (graph.nodes.isEmpty) return BranchFlowLayout.empty;

  final byId = {for (final n in graph.nodes) n.id: n};
  final childrenByParent = <String, List<BranchFlowNode>>{};
  for (final n in graph.nodes) {
    childrenByParent.putIfAbsent(n.parentId ?? '', () => []).add(n);
  }
  for (final list in childrenByParent.values) {
    list.sort(compareBranchNodes);
  }

  final depthById = <String, int>{};
  int depthOf(String id) {
    final cached = depthById[id];
    if (cached != null) return cached;
    final parent = byId[id]?.parentId;
    final d = (parent == null || !byId.containsKey(parent))
        ? 0
        : depthOf(parent) + 1;
    depthById[id] = d;
    return d;
  }

  final xById = <String, double>{};
  final visited = <String>{};
  var nextColumn = 0;
  final stepX = kBranchNodeWidth + kBranchNodeSep;

  // Post-order walk: leaves consume columns left→right; a parent is centered
  // across the span of its children.
  double place(BranchFlowNode n) {
    if (!visited.add(n.id)) {
      return xById[n.id] ?? (nextColumn * stepX);
    }
    final children = childrenByParent[n.id] ?? const [];
    double x;
    if (children.isEmpty) {
      x = nextColumn * stepX;
      nextColumn++;
    } else {
      final first = place(children.first);
      final last = place(children.last);
      x = (first + last) / 2;
    }
    xById[n.id] = x;
    return x;
  }

  final roots = childrenByParent[''] ?? const [];
  for (final r in roots) {
    place(r);
  }
  // Any node not reached via roots (defensive: orphan/cycle) still gets a slot.
  for (final n in graph.nodes) {
    if (!xById.containsKey(n.id)) {
      xById[n.id] = nextColumn * stepX;
      nextColumn++;
    }
  }

  final placed = <BranchFlowPlacedNode>[];
  var maxX = 0.0;
  var maxY = 0.0;
  for (final n in graph.nodes) {
    final x = kBranchMargin + (xById[n.id] ?? 0);
    final y = kBranchMargin + depthOf(n.id) * (kBranchNodeHeight + kBranchRankSep);
    placed.add(BranchFlowPlacedNode(node: n, offset: Offset(x, y)));
    if (x + kBranchNodeWidth > maxX) maxX = x + kBranchNodeWidth;
    if (y + kBranchNodeHeight > maxY) maxY = y + kBranchNodeHeight;
  }

  return BranchFlowLayout(
    placed: placed,
    edges: graph.edges,
    size: Size(maxX + kBranchMargin, maxY + kBranchMargin),
    activeNodeId: graph.activeNodeId,
    stats: graph.stats,
  );
}
