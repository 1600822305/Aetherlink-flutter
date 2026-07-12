// 文件树排序（纯 Dart，移动端/桌面端共用）。目录始终排在文件前面，
// 同类内按所选键比较，键相同回退到名称，保证顺序稳定。

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// 文件树排序方式。
enum TreeSortMode {
  /// 名称 A→Z（默认，不区分大小写）。
  nameAsc,

  /// 修改时间 新→旧。
  mtimeDesc,

  /// 大小 大→小（目录之间按名称）。
  sizeDesc;

  /// 持久化字符串（[name]）反解析；无效值回退默认。
  static TreeSortMode fromName(String? raw) {
    for (final m in TreeSortMode.values) {
      if (m.name == raw) return m;
    }
    return TreeSortMode.nameAsc;
  }
}

/// 按 [mode] 返回排好序的新列表（不修改入参）。
List<WorkspaceEntry> sortTreeEntries(
  List<WorkspaceEntry> entries,
  TreeSortMode mode,
) {
  int byName(WorkspaceEntry a, WorkspaceEntry b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  int cmp(WorkspaceEntry a, WorkspaceEntry b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    switch (mode) {
      case TreeSortMode.nameAsc:
        return byName(a, b);
      case TreeSortMode.mtimeDesc:
        final d = b.mtime.compareTo(a.mtime);
        return d != 0 ? d : byName(a, b);
      case TreeSortMode.sizeDesc:
        if (a.isDirectory) return byName(a, b);
        final d = b.size.compareTo(a.size);
        return d != 0 ? d : byName(a, b);
    }
  }

  return [...entries]..sort(cmp);
}
