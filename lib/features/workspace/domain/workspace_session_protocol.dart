// 长驻会话里跑一条命令的「哨兵标记」协议（纯 Dart，可单测）。
//
// PTY 是合并流（stdout+stderr+回显），无法像一次性 exec 那样拿到干净的退出码。
// 做法与 tmux 类 Agent 一致：命令后追加一行 printf 哨兵，输出里扫到
// `__AETHER_DONE_<nonce>_<exitCode>__` 即认为该命令结束。

/// 组装发往长驻 shell 的输入：先执行 [command]，随后打印带 [nonce] 的哨兵行
/// （携带 `$?`）。[command] 可多行；`$?` 取最后一条命令的退出码。
String buildSentinelInput(String command, String nonce) {
  final trimmed = command.trimRight();
  return '$trimmed\nprintf \'\\n__AETHER_DONE_${nonce}_%s__\\n\' "\$?"\n';
}

/// 在 [output] 中扫描 [nonce] 对应的哨兵。命中时返回哨兵前的输出与退出码；
/// 未命中返回 null（命令仍在跑）。
///
/// PTY 会回显输入，因此 [output] 里也含 printf 哨兵行本身的回显——回显里的
/// 哨兵字面量不带真实退出码（是 `%s__' "$?"` 原文），不会被误匹配。
SentinelMatch? matchSentinel(String output, String nonce) {
  final marker = RegExp('__AETHER_DONE_${RegExp.escape(nonce)}_(-?\\d+)__');
  final match = marker.firstMatch(output);
  if (match == null) return null;
  var head = output.substring(0, match.start);
  // 去掉哨兵行行首残留（printf 输出前置的 \n 已计入 head 尾部）。
  head = head.trimRight();
  return SentinelMatch(
    output: head,
    exitCode: int.parse(match.group(1)!),
  );
}

/// 组装会话建立后注入工作区环境变量的 export 命令（双作用域设计稿 §3.1，
/// 如 `WORKSPACE_ROOT` / `WORKSPACE_NAME`）。值用单引号包裹并转义内嵌单引号，
/// 防止 shell 注入。空 map 返回空串。
String buildExportCommand(Map<String, String> environment) {
  if (environment.isEmpty) return '';
  final parts = <String>[
    for (final entry in environment.entries)
      "${entry.key}='${entry.value.replaceAll("'", r"'\''")}'",
  ];
  return 'export ${parts.join(' ')}\n';
}

/// 会话建立后的环境初始化命令：含 `HOME` 时先 `mkdir -p` 确保独立 HOME
/// 目录存在（L2 语言级隔离，双作用域设计稿 §4 P5），再 export 全部变量。
String buildSessionEnvSetup(Map<String, String> environment) {
  if (environment.isEmpty) return '';
  final home = environment['HOME'];
  final mkdir = home == null
      ? ''
      : "mkdir -p '${home.replaceAll("'", r"'\''")}'\n";
  return '$mkdir${buildExportCommand(environment)}';
}

class SentinelMatch {
  const SentinelMatch({required this.output, required this.exitCode});

  /// 哨兵之前的全部会话输出（含 PTY 回显）。
  final String output;
  final int exitCode;
}
