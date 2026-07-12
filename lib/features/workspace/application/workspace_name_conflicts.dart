// 重名冲突的纯逻辑：按「name (2).ext」风格生成一个不与 [taken] 冲突的
// 文件/目录名（"保留两者"用）。只处理名字字符串，不涉及 opaque 路径。

/// Returns [name] itself when it's free, otherwise the first
/// `base (2).ext` / `base (3).ext` … variant not present in [taken].
/// [taken] should contain the sibling names of the destination directory
/// (and, for a rename-in-place flow, the source directory too).
String resolveDuplicateName(String name, Set<String> taken) {
  if (!taken.contains(name)) return name;
  final dot = name.lastIndexOf('.');
  // A leading dot (`.gitignore`) is part of the base name, not an extension.
  final hasExt = dot > 0;
  final base = hasExt ? name.substring(0, dot) : name;
  final ext = hasExt ? name.substring(dot) : '';
  for (var i = 2; ; i++) {
    final candidate = '$base ($i)$ext';
    if (!taken.contains(candidate)) return candidate;
  }
}
