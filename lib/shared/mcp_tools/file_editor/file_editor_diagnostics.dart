// `get_diagnostics` 的纯函数核心：按项目根目录内容选择静态分析命令、
// 组装/截断输出。与后端解耦以便单测（handler 只做工作区解析 + exec）。

/// 项目类型 → 静态分析命令的探测结果。
class DiagnosticsCommand {
  const DiagnosticsCommand({
    required this.projectType,
    required this.command,
  });

  final String projectType;
  final String command;
}

/// 按根目录条目名探测项目类型并给出只读分析命令；
/// 未识别时返回 null。命令固定白名单（不接受模型自定义命令），
/// 保证该工具始终只读、无需审批。
DiagnosticsCommand? diagnosticsCommandFor(Set<String> rootEntryNames) {
  if (rootEntryNames.contains('pubspec.yaml')) {
    return const DiagnosticsCommand(
      projectType: 'dart/flutter',
      command: 'dart analyze',
    );
  }
  if (rootEntryNames.contains('tsconfig.json')) {
    return const DiagnosticsCommand(
      projectType: 'typescript',
      command: 'npx tsc --noEmit --pretty false',
    );
  }
  if (rootEntryNames.contains('go.mod')) {
    return const DiagnosticsCommand(
      projectType: 'go',
      command: 'go vet ./...',
    );
  }
  if (rootEntryNames.contains('Cargo.toml')) {
    return const DiagnosticsCommand(
      projectType: 'rust',
      command: 'cargo check --quiet --message-format short',
    );
  }
  return null;
}

/// 诊断输出上限：分析器把错误排在前面，超限截尾保留头部。
const int kMaxDiagnosticsChars = 12000;

/// 合并 stdout/stderr 并截断到 [kMaxDiagnosticsChars]。
String combineDiagnosticsOutput(String stdout, String stderr) {
  final combined = [
    if (stdout.trim().isNotEmpty) stdout.trim(),
    if (stderr.trim().isNotEmpty) stderr.trim(),
  ].join('\n');
  if (combined.length <= kMaxDiagnosticsChars) return combined;
  return '${combined.substring(0, kMaxDiagnosticsChars)}\n…(输出过长已截断)';
}
