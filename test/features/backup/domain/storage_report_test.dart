import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';

void main() {
  test('formats byte boundaries and rejects negative display sizes', () {
    expect(formatStorageBytes(-1), '0 B');
    expect(formatStorageBytes(0), '0 B');
    expect(formatStorageBytes(1023), '1023 B');
    expect(formatStorageBytes(1024), '1.0 KB');
    expect(formatStorageBytes(1536), '1.5 KB');
    expect(formatStorageBytes(1024 * 1024), '1.0 MB');
    expect(formatStorageBytes(1024 * 1024 * 1024), '1.0 GB');
  });

  test('shares normalize sizes and handle empty or invalid input', () {
    expect(storageShares([]), isEmpty);
    expect(storageShares([0, 0]), [0.0, 0.0]);
    expect(storageShares([-10, 0]), [0.0, 0.0]);
    expect(storageShares([1, 3, 0, -2]), [0.25, 0.75, 0.0, 0.0]);
    final shares = storageShares([100, 1, 900]);
    expect(shares.reduce((a, b) => a + b), closeTo(1, 0.000001));
  });

  test('report aggregates categories without counting absent directories', () {
    final input = <StorageCategory, StorageUsage>{
      StorageCategory.chat: const StorageUsage(bytes: 100, fileCount: 3),
      StorageCategory.fonts:
          const StorageUsage(bytes: 20, fileCount: 2) +
          const StorageUsage(bytes: 30, fileCount: 1),
    };
    final report = StorageReport(input);
    input.clear();
    expect(report.totalBytes, 150);
    expect(report.totalFiles, 6);
    expect(report.categories.length, StorageCategory.values.length);
    expect(report.categories[StorageCategory.notes]!.bytes, 0);
    expect(
      () => report.categories.clear(),
      throwsUnsupportedError,
    );
    expect(StorageReport({}).totalBytes, 0);
    expect(StorageReport({}).totalFiles, 0);
  });

  test('report retains immutable details without double-counting totals', () {
    final items = <StorageItem>[
      const StorageItem(id: 'tmp', category: StorageCategory.terminal,
        name: 'tmp', path: '/support/terminal/tmp',
        usage: StorageUsage(bytes: 12, fileCount: 1), canClean: true),
    ];
    final report = StorageReport({
      StorageCategory.terminal: const StorageUsage(bytes: 12, fileCount: 1),
    }, items: items);
    items.clear();
    expect(report.itemsFor(StorageCategory.terminal).single.name, 'tmp');
    expect(report.itemsFor(StorageCategory.chat), isEmpty);
    expect(report.totalBytes, 12);
    expect(() => report.items.clear(), throwsUnsupportedError);
    expect(StorageReport({}).items, isEmpty);
  });
}
