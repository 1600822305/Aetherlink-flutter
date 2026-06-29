import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/message_tree_builder.dart';

/// Unit tests for the Dart port of Cherry's `buildMessageTree` /
/// `findActiveNodeId` (see docs/design/message-tree-model-design.md §9).
void main() {
  var clock = DateTime.utc(2024, 1, 1);

  Message msg(
    String id, {
    MessageRole role = MessageRole.assistant,
    String? askId,
    bool? foldSelected,
  }) {
    clock = clock.add(const Duration(seconds: 1));
    return Message(
      id: id,
      role: role,
      assistantId: 'a',
      topicId: 't',
      createdAt: clock,
      status: MessageStatus.success,
      askId: askId,
      foldSelected: foldSelected,
    );
  }

  group('buildMessageTree', () {
    test('empty input yields an empty tree', () {
      expect(buildMessageTree(const []), isEmpty);
    });

    test('a linear conversation chains parent = previous message', () {
      final tree = buildMessageTree([
        msg('u1', role: MessageRole.user),
        msg('a1'),
        msg('u2', role: MessageRole.user),
        msg('a2'),
      ]);

      expect(tree['u1'], (parentId: null, siblingsGroupId: 0));
      expect(tree['a1'], (parentId: 'u1', siblingsGroupId: 0));
      expect(tree['u2'], (parentId: 'a1', siblingsGroupId: 0));
      expect(tree['a2'], (parentId: 'u2', siblingsGroupId: 0));
    });

    test('multi-model replies form a sibling group under the user message', () {
      // Mirrors the Cherry docstring example.
      final tree = buildMessageTree([
        msg('u1', role: MessageRole.user),
        msg('a1', askId: 'u1'),
        msg('a2', askId: 'u1', foldSelected: true),
        msg('a3', askId: 'u1'),
        msg('u2', role: MessageRole.user),
        msg('a4', askId: 'u2'), // single reply → not a group
      ]);

      expect(tree['u1']!.parentId, isNull);
      expect(tree['a1'], (parentId: 'u1', siblingsGroupId: 1));
      expect(tree['a2'], (parentId: 'u1', siblingsGroupId: 1));
      expect(tree['a3'], (parentId: 'u1', siblingsGroupId: 1));
      // The next user message links to the foldSelected reply.
      expect(tree['u2'], (parentId: 'a2', siblingsGroupId: 0));
      // Single reply is not a sibling group.
      expect(tree['a4'], (parentId: 'u2', siblingsGroupId: 0));
    });

    test('without foldSelected, the next user message links to the last member', () {
      final tree = buildMessageTree([
        msg('u1', role: MessageRole.user),
        msg('a1', askId: 'u1'),
        msg('a2', askId: 'u1'),
        msg('u2', role: MessageRole.user),
      ]);

      expect(tree['a1']!.siblingsGroupId, 1);
      expect(tree['a2']!.siblingsGroupId, 1);
      expect(tree['u2'], (parentId: 'a2', siblingsGroupId: 0));
    });

    test('orphaned group (asked user deleted) shares a fallback parent', () {
      final tree = buildMessageTree([
        msg('x0', role: MessageRole.user),
        msg('a1', askId: 'gone'),
        msg('a2', askId: 'gone'),
      ]);

      expect(tree['x0'], (parentId: null, siblingsGroupId: 0));
      // Both orphans share the fallback parent (previous message x0) and group.
      expect(tree['a1'], (parentId: 'x0', siblingsGroupId: 1));
      expect(tree['a2'], (parentId: 'x0', siblingsGroupId: 1));
    });

    test('distinct multi-model groups get distinct sibling ids', () {
      final tree = buildMessageTree([
        msg('u1', role: MessageRole.user),
        msg('a1', askId: 'u1'),
        msg('a2', askId: 'u1'),
        msg('u2', role: MessageRole.user),
        msg('b1', askId: 'u2'),
        msg('b2', askId: 'u2'),
      ]);

      expect(tree['a1']!.siblingsGroupId, 1);
      expect(tree['a2']!.siblingsGroupId, 1);
      expect(tree['b1']!.siblingsGroupId, 2);
      expect(tree['b2']!.siblingsGroupId, 2);
    });
  });

  group('findActiveNodeId', () {
    test('empty → null', () {
      expect(findActiveNodeId(const []), isNull);
    });

    test('linear → last message id', () {
      final id = findActiveNodeId([
        msg('u1', role: MessageRole.user),
        msg('a1'),
      ]);
      expect(id, 'a1');
    });

    test('last message in a group → the foldSelected sibling', () {
      final id = findActiveNodeId([
        msg('u1', role: MessageRole.user),
        msg('a1', askId: 'u1', foldSelected: true),
        msg('a2', askId: 'u1'),
      ]);
      expect(id, 'a1');
    });

    test('last message in a group with no foldSelected → last message id', () {
      final id = findActiveNodeId([
        msg('u1', role: MessageRole.user),
        msg('a1', askId: 'u1'),
        msg('a2', askId: 'u1'),
      ]);
      expect(id, 'a2');
    });
  });

  group('validateTree', () {
    test('a valid tree (parents mapped to root) has no problems', () {
      final tree = <String, TreePlacement>{
        'u1': (parentId: 'root', siblingsGroupId: 0),
        'a1': (parentId: 'u1', siblingsGroupId: 0),
      };
      expect(validateTree(tree, rootId: 'root'), isEmpty);
    });

    test('flags a null parent', () {
      final tree = <String, TreePlacement>{
        'u1': (parentId: null, siblingsGroupId: 0),
      };
      expect(validateTree(tree, rootId: 'root'), isNotEmpty);
    });

    test('flags a cycle', () {
      final tree = <String, TreePlacement>{
        'a': (parentId: 'b', siblingsGroupId: 0),
        'b': (parentId: 'a', siblingsGroupId: 0),
      };
      expect(
        validateTree(tree, rootId: 'root'),
        contains(predicate<String>((p) => p.contains('cycle'))),
      );
    });
  });
}
