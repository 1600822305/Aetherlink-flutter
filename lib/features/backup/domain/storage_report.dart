enum StorageCategory {
  chat,
  backups,
  tools,
  avatars,
  fonts,
  notes,
  cache,
  other,
  workspaceHistory,
  terminal,
  images,
  files,
}

enum StorageCleanup { cache, tools, fontCache, workspaceHistory }

class StorageItem {
  const StorageItem({
    required this.id,
    required this.category,
    required this.name,
    required this.path,
    required this.usage,
    this.canClean = false,
  });

  final String id;
  final StorageCategory category;
  final String name;
  final String path;
  final StorageUsage usage;
  final bool canClean;
}

class StorageUsage {
  const StorageUsage({this.bytes = 0, this.fileCount = 0});

  final int bytes;
  final int fileCount;

  StorageUsage operator +(StorageUsage other) => StorageUsage(
    bytes: bytes + other.bytes,
    fileCount: fileCount + other.fileCount,
  );
}

class StorageReport {
  StorageReport(
    Map<StorageCategory, StorageUsage> categories, {
    this.canCleanCache = false,
    List<StorageItem> items = const [],
  }) : categories = Map.unmodifiable({
        for (final category in StorageCategory.values)
          category: categories[category] ?? const StorageUsage(),
      }),
       items = List.unmodifiable(items);

  final Map<StorageCategory, StorageUsage> categories;
  final bool canCleanCache;
  final List<StorageItem> items;

  List<StorageItem> itemsFor(StorageCategory category) =>
      items.where((item) => item.category == category).toList();

  int get totalBytes =>
      categories.values.fold(0, (sum, item) => sum + item.bytes);

  int get totalFiles =>
      categories.values.fold(0, (sum, item) => sum + item.fileCount);
}

List<double> storageShares(Iterable<int> sizes) {
  final values = sizes.map((size) => size < 0 ? 0 : size).toList();
  final total = values.fold<int>(0, (sum, value) => sum + value);
  return [for (final value in values) total == 0 ? 0.0 : value / total];
}

String formatStorageBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  return '${value.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
}
