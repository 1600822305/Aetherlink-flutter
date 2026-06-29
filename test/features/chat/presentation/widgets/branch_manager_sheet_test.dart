import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/flow/branch_flow_graph.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/flow/branch_flow_layout.dart';

/// Unit tests for the pure 分支管理 graph builder + layout (`buildBranchFlowGraph`
/// / `layoutBranchFlowGraph`), the data behind the TopicMessageFlow canvas.
void main() {
  var clock = DateTime.utc(2024, 1, 1);
  Message node(
    String id, {
    required MessageRole role,
    String? parentId,
  }) {
    clock = clock.add(const Duration(seconds: 1));
    return Message(
      id: id,
      role: role,
      assistantId: 'a',
      topicId: 't',
      parentId: parentId,
      createdAt: clock,
      status: MessageStatus.success,
    );
  }

  BranchFlowNode nodeOf(BranchFlowGraph g, String id) =>
      g.nodes.firstWhere((n) => n.id == id);
  BranchFlowEdge edgeOf(BranchFlowGraph g, String target) =>
      g.edges.firstWhere((e) => e.target == target);

  test('linear chat: every node on the active path, 0 branches', () {
    final messages = [
      node('u1', role: MessageRole.user, parentId: 'root'),
      node('a1', role: MessageRole.assistant, parentId: 'u1'),
      node('u2', role: MessageRole.user, parentId: 'a1'),
      node('a2', role: MessageRole.assistant, parentId: 'u2'),
    ];
    final g = buildBranchFlowGraph(messages, rootId: 'root', activeNodeId: 'a2');

    expect(g.stats.nodeCount, 4);
    expect(g.stats.branchCount, 0); // one leaf
    expect(g.stats.activePathLength, 4);
    expect(g.nodes.every((n) => n.isOnActivePath), isTrue);
    expect(g.nodes.every((n) => !n.isInactiveBranch), isTrue);
    expect(g.nodes.where((n) => n.isActive).map((n) => n.id), ['a2']);
    // u1 is a graph root (parent is the virtual root) so it has no edge.
    expect(g.edges.map((e) => e.target).toSet(), {'a1', 'u2', 'a2'});
    expect(g.edges.every((e) => e.state == BranchFlowEdgeState.active), isTrue);
  });

  test('fork: off-path branch is marked 已禁用, both leaves counted', () {
    // a1 forks into two follow-ups: u2→a2 (active) and u3→a3 (off-path).
    final messages = [
      node('u1', role: MessageRole.user, parentId: 'root'),
      node('a1', role: MessageRole.assistant, parentId: 'u1'),
      node('u2', role: MessageRole.user, parentId: 'a1'),
      node('a2', role: MessageRole.assistant, parentId: 'u2'),
      node('u3', role: MessageRole.user, parentId: 'a1'),
      node('a3', role: MessageRole.assistant, parentId: 'u3'),
    ];
    final g = buildBranchFlowGraph(messages, rootId: 'root', activeNodeId: 'a2');

    expect(g.stats.nodeCount, 6);
    expect(g.stats.branchCount, 2); // two leaves (a2, a3)

    for (final id in ['u1', 'a1', 'u2', 'a2']) {
      expect(nodeOf(g, id).isOnActivePath, isTrue, reason: '$id on path');
      expect(nodeOf(g, id).isInactiveBranch, isFalse, reason: '$id not disabled');
    }
    for (final id in ['u3', 'a3']) {
      expect(nodeOf(g, id).isOnActivePath, isFalse, reason: '$id off path');
      expect(nodeOf(g, id).isInactiveBranch, isTrue, reason: '$id disabled');
    }
    expect(nodeOf(g, 'a2').isActive, isTrue);
    expect(nodeOf(g, 'a3').isActive, isFalse);
    // Edge states: active path green, off-path inactive.
    expect(edgeOf(g, 'a2').state, BranchFlowEdgeState.active);
    expect(edgeOf(g, 'u3').state, BranchFlowEdgeState.inactive);
  });

  test('assistant fork is marked as a sibling branch when no active node', () {
    // Two assistant replies under the same user message (regenerate / multi-model).
    final messages = [
      node('u1', role: MessageRole.user, parentId: 'root'),
      node('a1', role: MessageRole.assistant, parentId: 'u1'),
      node('a2', role: MessageRole.assistant, parentId: 'u1'),
    ];
    final g = buildBranchFlowGraph(messages, rootId: 'root', activeNodeId: null);

    expect(nodeOf(g, 'a1').isSiblingBranch, isTrue);
    expect(nodeOf(g, 'a2').isSiblingBranch, isTrue);
    expect(edgeOf(g, 'a1').state, BranchFlowEdgeState.sibling);
    expect(g.nodes.every((n) => !n.isOnActivePath), isTrue);
    expect(g.nodes.every((n) => !n.isInactiveBranch), isTrue);
  });

  test('empty topic builds an empty graph and layout', () {
    final g = buildBranchFlowGraph(const [], rootId: 'root', activeNodeId: null);
    expect(g.nodes, isEmpty);
    expect(layoutBranchFlowGraph(g).placed, isEmpty);
  });

  test('layout: children are deeper (higher y) and centered under parent', () {
    final messages = [
      node('u1', role: MessageRole.user, parentId: 'root'),
      node('a1', role: MessageRole.assistant, parentId: 'u1'),
      node('u2', role: MessageRole.user, parentId: 'a1'),
      node('u3', role: MessageRole.user, parentId: 'a1'),
    ];
    final g = buildBranchFlowGraph(messages, rootId: 'root', activeNodeId: 'u2');
    final layout = layoutBranchFlowGraph(g);

    final u1 = layout.byId('u1')!;
    final a1 = layout.byId('a1')!;
    final u2 = layout.byId('u2')!;
    final u3 = layout.byId('u3')!;

    // Depth grows downward.
    expect(a1.offset.dy, greaterThan(u1.offset.dy));
    expect(u2.offset.dy, greaterThan(a1.offset.dy));
    expect(u2.offset.dy, u3.offset.dy); // same depth
    // Parent a1 is horizontally centered between its two children.
    expect(a1.center.dx, closeTo((u2.center.dx + u3.center.dx) / 2, 0.01));
    expect(layout.size.width, greaterThan(0));
  });
}
