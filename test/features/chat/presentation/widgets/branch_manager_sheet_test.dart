import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/branch_manager_sheet.dart';

/// Unit tests for the pure 分支管理 tree builder (`buildBranchTree`).
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

  test('linear chat: every node on the active path, 0 branches', () {
    final messages = [
      node('u1', role: MessageRole.user, parentId: 'root'),
      node('a1', role: MessageRole.assistant, parentId: 'u1'),
      node('u2', role: MessageRole.user, parentId: 'a1'),
      node('a2', role: MessageRole.assistant, parentId: 'u2'),
    ];
    final tree = buildBranchTree(messages, rootId: 'root', activeNodeId: 'a2');

    expect(tree.nodeCount, 4);
    expect(tree.branchCount, 0); // one leaf
    expect(tree.rows.map((r) => r.message.id), ['u1', 'a1', 'u2', 'a2']);
    expect(tree.rows.map((r) => r.depth), [0, 1, 2, 3]);
    expect(tree.rows.every((r) => r.isOnActivePath), isTrue);
    expect(tree.rows.every((r) => !r.isInactiveBranch), isTrue);
    // Only the active leaf a2 is marked active.
    expect(tree.rows.where((r) => r.isActive).map((r) => r.message.id), ['a2']);
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
    final tree = buildBranchTree(messages, rootId: 'root', activeNodeId: 'a2');

    expect(tree.nodeCount, 6);
    expect(tree.branchCount, 2); // two leaves (a2, a3)

    BranchTreeRow rowOf(String id) =>
        tree.rows.firstWhere((r) => r.message.id == id);

    // Active path: u1 → a1 → u2 → a2.
    for (final id in ['u1', 'a1', 'u2', 'a2']) {
      expect(rowOf(id).isOnActivePath, isTrue, reason: '$id on path');
      expect(rowOf(id).isInactiveBranch, isFalse, reason: '$id not disabled');
    }
    // Off-path branch: u3 → a3.
    for (final id in ['u3', 'a3']) {
      expect(rowOf(id).isOnActivePath, isFalse, reason: '$id off path');
      expect(rowOf(id).isInactiveBranch, isTrue, reason: '$id disabled');
    }
    expect(rowOf('a2').isActive, isTrue);
    expect(rowOf('a3').isActive, isFalse);
    // DFS pre-order keeps each branch contiguous and children indented.
    expect(rowOf('u2').depth, 2);
    expect(rowOf('u3').depth, 2);
  });

  test('no active node: nothing is on-path or disabled', () {
    final messages = [
      node('u1', role: MessageRole.user, parentId: 'root'),
      node('a1', role: MessageRole.assistant, parentId: 'u1'),
    ];
    final tree = buildBranchTree(messages, rootId: 'root', activeNodeId: null);
    expect(tree.rows.every((r) => !r.isOnActivePath), isTrue);
    expect(tree.rows.every((r) => !r.isInactiveBranch), isTrue);
  });

  test('empty topic builds an empty tree', () {
    expect(
      buildBranchTree(const [], rootId: 'root', activeNodeId: null).rows,
      isEmpty,
    );
  });
}
