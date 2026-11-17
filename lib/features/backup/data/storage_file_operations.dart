import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';

class StoragePathSpec {
  const StoragePathSpec({
    required this.id,
    required this.category,
    required this.name,
    required this.root,
    required this.path,
    this.canClean = false,
    this.isContainer = false,
    this.childNames = const {},
    this.excludedPaths = const [],
  });

  final String id;
  final StorageCategory category;
  final String name;
  final String root;
  final String path;
  final bool canClean;
  final bool isContainer;
  final Map<String, String> childNames;
  final List<String> excludedPaths;
}

bool isStoragePathSafe(String root, String path) {
  if (!p.isAbsolute(root) || !p.isAbsolute(path) ||
      p.split(root).contains('..') || p.split(path).contains('..')) {
    return false;
  }
  final base = p.normalize(p.absolute(root));
  final target = p.normalize(p.absolute(path));
  if (base != target && !p.isWithin(base, target)) return false;
  var current = base;
  if (FileSystemEntity.typeSync(current, followLinks: false) ==
      FileSystemEntityType.link) {
    return false;
  }
  if (base == target) return true;
  for (final part in p.split(p.relative(target, from: base))) {
    current = p.join(current, part);
    if (FileSystemEntity.typeSync(current, followLinks: false) ==
        FileSystemEntityType.link) {
      return false;
    }
  }
  return true;
}

List<StoragePathSpec> _expand(List<StoragePathSpec> paths) {
  final expanded = <StoragePathSpec>[];
  for (final spec in paths) {
    if (!spec.isContainer) {
      expanded.add(spec);
      continue;
    }
    try {
      if (!isStoragePathSafe(spec.root, spec.path) ||
          FileSystemEntity.typeSync(spec.path, followLinks: false) !=
              FileSystemEntityType.directory) {
        continue;
      }
      final children = Directory(spec.path).listSync(followLinks: false)
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final child in children) {
        if (FileSystemEntity.typeSync(child.path, followLinks: false) !=
            FileSystemEntityType.directory) {
          continue;
        }
        final id = p.basename(child.path);
        expanded.add(StoragePathSpec(
          id: '${spec.id}:$id',
          category: spec.category,
          name: spec.childNames[id]?.trim().isNotEmpty == true
              ? spec.childNames[id]!
              : id,
          root: spec.root,
          path: child.path,
          canClean: spec.canClean,
        ));
      }
    } on FileSystemException {
      continue;
    }
  }
  return expanded;
}

StorageReport scanStoragePaths(
  List<StoragePathSpec> paths, {
  required bool canCleanCache,
}) {
  final items = <StorageItem>[];
  final categories = <StorageCategory, StorageUsage>{};
  for (final spec in _expand(paths)) {
    try {
      if (!isStoragePathSafe(spec.root, spec.path)) continue;
      final type = FileSystemEntity.typeSync(spec.path, followLinks: false);
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.directory) {
        continue;
      }
      final usage = _measure(spec.path, spec.excludedPaths);
      items.add(StorageItem(
        id: spec.id,
        category: spec.category,
        name: spec.name,
        path: spec.path,
        usage: usage,
        canClean: spec.canClean,
      ));
      categories[spec.category] =
          (categories[spec.category] ?? const StorageUsage()) + usage;
    } on FileSystemException {
      continue;
    }
  }
  return StorageReport(categories, items: items, canCleanCache: canCleanCache);
}

bool _isExcluded(String path, List<String> exclusions) =>
    exclusions.any((excluded) => p.equals(path, excluded));

StorageUsage _measure(String path, List<String> exclusions) {
  if (_isExcluded(path, exclusions)) return const StorageUsage();
  try {
    switch (FileSystemEntity.typeSync(path, followLinks: false)) {
      case FileSystemEntityType.file:
        return StorageUsage(bytes: File(path).lengthSync(), fileCount: 1);
      case FileSystemEntityType.directory:
        var total = const StorageUsage();
        for (final child in Directory(path).listSync(followLinks: false)) {
          total += _measure(child.path, exclusions);
        }
        return total;
      default:
        return const StorageUsage();
    }
  } on FileSystemException {
    return const StorageUsage();
  }
}

void cleanStorageItem(List<StoragePathSpec> paths, String id) {
  final matches = _expand(paths).where((spec) => spec.id == id).toList();
  if (matches.length != 1 || !matches.single.canClean) {
    throw ArgumentError.value(id, 'id', '此项目不可清理');
  }
  clearStoragePaths(matches);
}

void clearStoragePaths(List<StoragePathSpec> paths) {
  for (final spec in paths) {
    if (!spec.canClean || !isStoragePathSafe(spec.root, spec.path)) {
      throw FileSystemException('清理路径不在允许范围内或包含符号链接', spec.path);
    }
  }
  var failures = 0;
  void remove(String root, String path, List<String> exclusions) {
    if (_isExcluded(path, exclusions)) return;
    if (!p.isWithin(root, path)) {
      failures++;
      return;
    }
    try {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        for (final child in Directory(path).listSync(followLinks: false)) {
          remove(root, child.path, exclusions);
        }
        Directory(path).deleteSync();
      } else if (type == FileSystemEntityType.file) {
        File(path).deleteSync();
      } else if (type == FileSystemEntityType.link) {
        Link(path).deleteSync();
      }
    } on FileSystemException {
      failures++;
    }
  }

  for (final spec in paths) {
    try {
      final type = FileSystemEntity.typeSync(spec.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.directory) {
        failures++;
        continue;
      }
      for (final child in Directory(spec.path).listSync(followLinks: false)) {
        remove(spec.path, child.path, spec.excludedPaths);
      }
    } on FileSystemException {
      failures++;
    }
  }
  if (failures > 0) {
    throw FileSystemException('有 $failures 个项目未能移除，请稍后重试');
  }
}
