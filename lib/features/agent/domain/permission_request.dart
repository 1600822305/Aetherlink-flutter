// 工具调用参数 → 权限判定 patterns 的纯映射（审批重构 PR2）。
// 终端命令的映射见 shell_command_patterns.dart；这里放其余工具组。

/// 文件编辑器写工具参与权限判定的 patterns：取出调用涉及的全部路径参数
/// （path / parent_path / source_path / destination_path），规则里可写
/// `src/*` 这类路径模式。无路径参数时退化为 `*`（按整工具判定）。
List<String> fileEditorPermissionPatterns(Map<String, Object?> args) {
  const pathKeys = ['path', 'parent_path', 'source_path', 'destination_path'];
  final patterns = <String>[];
  for (final key in pathKeys) {
    final value = args[key];
    if (value is! String || value.trim().isEmpty) continue;
    if (!patterns.contains(value.trim())) patterns.add(value.trim());
  }
  return patterns.isEmpty ? const ['*'] : patterns;
}

/// 终端工具调用里实际要执行的命令文本：terminal_execute 取 `command`，
/// terminal_session（action=write）取 `input`（写入 shell 提示符等同执行）。
/// 非命令类调用返回 null。
String? terminalCommandText(String toolName, Map<String, Object?> args) {
  final value = switch (toolName) {
    'terminal_execute' => args['command'],
    'terminal_session' => args['input'],
    _ => null,
  };
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}
