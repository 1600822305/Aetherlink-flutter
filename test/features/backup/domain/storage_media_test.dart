import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/backup/domain/storage_media.dart';

void main() {
  StorageMedia item(String id, int bytes, int day, StorageMediaFilter filter,
      {bool isImage = true, bool isInUse = false}) => StorageMedia(
    id: id, name: id, source: '/$id', mimeType: isImage ? 'image/png' : 'text/plain',
    bytes: bytes, modifiedAt: DateTime(2026, 1, day), filter: filter, isInUse: isInUse,
  );

  final items = [
    item('block:chat', 30, 2, StorageMediaFilter.chat, isInUse: true),
    item('disk:tool', 10, 3, StorageMediaFilter.tools),
    item('disk:avatar', 20, 1, StorageMediaFilter.avatars),
    item('disk:file', 50, 4, StorageMediaFilter.tools, isImage: false),
  ];

  test('filters select only the visible image category and leave input untouched', () {
    for (final filter in StorageMediaFilter.values) {
      final visible = visibleStorageMedia(items, isImageView: true, filter: filter);
      expect(visible.every((item) => item.isImage), isTrue);
      expect(visible.length, filter == StorageMediaFilter.all ? 3 : 1);
      expect(visible.every((item) => filter == StorageMediaFilter.all || item.filter == filter), isTrue);
    }
    expect(items.length, 4);
    expect(visibleStorageMedia([], isImageView: true), isEmpty);
  });

  test('all four sorts are deterministic and retain the same selected identifiers', () {
    final selected = {'disk:tool', 'disk:avatar'};
    final expected = {
      StorageMediaSort.newest: ['disk:tool', 'block:chat', 'disk:avatar'],
      StorageMediaSort.oldest: ['disk:avatar', 'block:chat', 'disk:tool'],
      StorageMediaSort.largest: ['block:chat', 'disk:avatar', 'disk:tool'],
      StorageMediaSort.smallest: ['disk:tool', 'disk:avatar', 'block:chat'],
    };
    for (final sort in StorageMediaSort.values) {
      final visible = visibleStorageMedia(items, isImageView: true, sort: sort);
      expect(visible.map((item) => item.id), expected[sort]);
      expect(visible.map((item) => item.id).toSet().intersection(selected), selected);
    }
  });

  test('files always sort by descending modification time and protect chat blocks', () {
    final files = [
      item('disk:a', 100, 1, StorageMediaFilter.tools, isImage: false),
      item('disk:b', 1, 2, StorageMediaFilter.tools, isImage: false),
    ];
    expect(visibleStorageMedia(files, isImageView: false, sort: StorageMediaSort.largest)
      .map((item) => item.id), ['disk:b', 'disk:a']);
    expect(items.first.canDelete, isFalse);
    expect(items[1].canDelete, isTrue);
  });
}
