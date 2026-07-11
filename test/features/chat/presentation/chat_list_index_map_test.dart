import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/presentation/controllers/chat_list_index_map.dart';

void main() {
  group('ChatListIndexMap forward', () {
    test('no edge, no hidden: identity mapping', () {
      const map = ChatListIndexMap(totalRows: 5, hiddenRows: 0, edgeCount: 0);
      expect(map.itemCount, 5);
      for (var i = 0; i < 5; i++) {
        expect(map.isEdge(i), isFalse);
        expect(map.rowOfListIndex(i), i);
        expect(map.listIndexOfRow(i), i);
      }
    });

    test('edge item sits at list index 0', () {
      const map = ChatListIndexMap(totalRows: 5, hiddenRows: 0, edgeCount: 1);
      expect(map.itemCount, 6);
      expect(map.isEdge(0), isTrue);
      expect(map.isEdge(1), isFalse);
      expect(map.rowOfListIndex(1), 0);
      expect(map.rowOfListIndex(5), 4);
      expect(map.listIndexOfRow(0), 1);
      expect(map.listIndexOfRow(4), 5);
    });

    test('hidden history shifts row/list conversion', () {
      const map = ChatListIndexMap(totalRows: 10, hiddenRows: 4, edgeCount: 1);
      expect(map.visibleRows, 6);
      expect(map.itemCount, 7);
      expect(map.isEdge(0), isTrue);
      // First visible row is full-row index 4.
      expect(map.rowOfListIndex(1), 4);
      expect(map.listIndexOfRow(4), 1);
      // Newest row 9 at the last list index.
      expect(map.rowOfListIndex(6), 9);
      expect(map.listIndexOfRow(9), 6);
      expect(map.isNewestRow(9), isTrue);
      expect(map.isNewestRow(8), isFalse);
    });

    test('round-trips across the visible range', () {
      const map = ChatListIndexMap(totalRows: 30, hiddenRows: 12, edgeCount: 1);
      for (var row = map.hiddenRows; row < map.totalRows; row++) {
        final li = map.listIndexOfRow(row);
        expect(map.isEdge(li), isFalse);
        expect(map.rowOfListIndex(li), row);
      }
    });
  });

  group('ChatListIndexMap reverse', () {
    test('list index 0 is the newest row', () {
      const map = ChatListIndexMap(
        totalRows: 5,
        hiddenRows: 0,
        edgeCount: 0,
        reverse: true,
      );
      expect(map.itemCount, 5);
      expect(map.rowOfListIndex(0), 4);
      expect(map.rowOfListIndex(4), 0);
      expect(map.listIndexOfRow(4), 0);
      expect(map.listIndexOfRow(0), 4);
    });

    test('edge item sits at the highest list index', () {
      const map = ChatListIndexMap(
        totalRows: 5,
        hiddenRows: 0,
        edgeCount: 1,
        reverse: true,
      );
      expect(map.itemCount, 6);
      expect(map.isEdge(5), isTrue);
      expect(map.isEdge(4), isFalse);
      expect(map.rowOfListIndex(0), 4);
      expect(map.rowOfListIndex(4), 0);
    });

    test('hidden history: oldest visible row before the edge item', () {
      const map = ChatListIndexMap(
        totalRows: 10,
        hiddenRows: 4,
        edgeCount: 1,
        reverse: true,
      );
      expect(map.visibleRows, 6);
      expect(map.itemCount, 7);
      // Newest row (9) at list index 0.
      expect(map.rowOfListIndex(0), 9);
      expect(map.listIndexOfRow(9), 0);
      // Oldest visible row (4) at list index 5; the edge item follows at 6.
      expect(map.rowOfListIndex(5), 4);
      expect(map.listIndexOfRow(4), 5);
      expect(map.isEdge(6), isTrue);
      expect(map.isEdge(5), isFalse);
    });

    test('round-trips across the visible range', () {
      const map = ChatListIndexMap(
        totalRows: 30,
        hiddenRows: 12,
        edgeCount: 1,
        reverse: true,
      );
      for (var row = map.hiddenRows; row < map.totalRows; row++) {
        final li = map.listIndexOfRow(row);
        expect(map.isEdge(li), isFalse);
        expect(map.rowOfListIndex(li), row);
      }
    });
  });
}
