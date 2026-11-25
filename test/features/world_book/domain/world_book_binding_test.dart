import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_binding.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

void main() {
  group('resolveWorldBookBinding', () {
    test('null topic list inherits the assistant', () {
      final b = resolveWorldBookBinding(
        assistantBookIds: const ['a', 'b'],
        topicBookIds: null,
      );
      expect(b.source, WorldBookBindingSource.assistant);
      expect(b.ids, ['a', 'b']);
    });

    test('empty topic list explicitly disables world books', () {
      final b = resolveWorldBookBinding(
        assistantBookIds: const ['a'],
        topicBookIds: const [],
      );
      expect(b.source, WorldBookBindingSource.topicDisabled);
      expect(b.ids, isEmpty);
    });

    test('a non-empty topic list overrides the assistant', () {
      final b = resolveWorldBookBinding(
        assistantBookIds: const ['a'],
        topicBookIds: const ['c'],
      );
      expect(b.source, WorldBookBindingSource.topicOverride);
      expect(b.ids, ['c']);
    });
  });

  test('activeWorldBooks keeps library order, drops disabled / missing', () {
    const books = [
      WorldBook(id: 'x'),
      WorldBook(id: 'y', enabled: false),
      WorldBook(id: 'z'),
    ];
    final binding = resolveWorldBookBinding(
      assistantBookIds: const ['z', 'y', 'gone', 'x'],
      topicBookIds: null,
    );
    expect(activeWorldBooks(binding, books).map((b) => b.id), ['x', 'z']);
  });

  group('persisted fields', () {
    final now = DateTime.utc(2024);
    Topic topic({List<String>? ids}) => Topic(
      id: 't',
      assistantId: 'a',
      name: 'n',
      createdAt: now,
      updatedAt: now,
      worldBookIds: ids,
    );

    Map<String, dynamic> roundTrip(Map<String, dynamic> json) =>
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

    test('Topic keeps null, [] and lists distinct through JSON', () {
      final legacy = roundTrip(topic().toJson())..remove('worldBookIds');
      expect(Topic.fromJson(legacy).worldBookIds, isNull);
      expect(Topic.fromJson(roundTrip(topic().toJson())).worldBookIds, isNull);
      expect(
        Topic.fromJson(roundTrip(topic(ids: const []).toJson())).worldBookIds,
        isEmpty,
      );
      expect(
        Topic.fromJson(roundTrip(topic(ids: const ['b']).toJson())).worldBookIds,
        ['b'],
      );
    });

    test('Topic.copyWith distinguishes omitted from explicit null', () {
      final overridden = topic(ids: const ['b']);
      expect(overridden.copyWith(name: 'x').worldBookIds, ['b']);
      expect(overridden.copyWith(worldBookIds: null).worldBookIds, isNull);
    });

    test('Assistant defaults worldBookIds to empty, also for legacy blobs', () {
      const assistant = Assistant(id: 'a', name: 'A');
      expect(assistant.worldBookIds, isEmpty);
      final legacy = roundTrip(assistant.toJson())..remove('worldBookIds');
      expect(Assistant.fromJson(legacy).worldBookIds, isEmpty);
      expect(
        Assistant.fromJson(
          roundTrip(assistant.copyWith(worldBookIds: const ['w']).toJson()),
        ).worldBookIds,
        ['w'],
      );
    });
  });
}
