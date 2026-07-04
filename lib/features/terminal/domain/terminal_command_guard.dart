// AI 发起命令的黑名单拦截（纯 Dart，可单测）。设计文档 §3 安全边界：
// 「支持命令黑名单（rm -rf / 等模式拦截）」。
//
// 只拦 AI 通道（terminal_execute / terminal_session_exec）；用户在交互式
// 终端里手动敲的命令不经过这里。rootfs 本身是沙箱，黑名单的意义是防止
// AI 误操作把整个 rootfs / 挂载目录清掉，让用户白装一遍环境。

class _BlockedPattern {
  const _BlockedPattern(this.pattern, this.reason);

  final RegExp pattern;
  final String reason;
}

final List<_BlockedPattern> _kBlockedPatterns = [
  _BlockedPattern(
    // rm -rf 指向根 / 家目录整体（/、/*、~、$HOME、/root），带不带别的
    // 标志顺序都算：rm -rf /、rm -fr /*、rm --recursive --force /。
    RegExp(
      r'\brm\s+(-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*|--recursive\s+--force|--force\s+--recursive)\s+("?/"?\*?|~/?|\$HOME/?|/root/?)\s*$',
    ),
    '递归删除根目录 / 家目录',
  ),
  _BlockedPattern(
    RegExp(r'\bmkfs(\.\w+)?\b'),
    '格式化文件系统',
  ),
  _BlockedPattern(
    RegExp(r'\bdd\b[^\n]*\bof=/dev/'),
    '直接写块设备',
  ),
  _BlockedPattern(
    RegExp(r'>\s*/dev/(sd[a-z]|block/)'),
    '重定向覆盖块设备',
  ),
  _BlockedPattern(
    RegExp(r':\(\)\s*\{\s*:\|\s*:\s*&\s*\}\s*;\s*:'),
    'fork 炸弹',
  ),
  _BlockedPattern(
    RegExp(r'\bchmod\s+(-[a-zA-Z]*R[a-zA-Z]*\s+)?[0-7]{3,4}\s+/\s*$'),
    '递归改根目录权限',
  ),
];

/// [command] 命中黑名单时返回拦截原因；安全时返回 null。
String? blockedCommandReason(String command) {
  for (final blocked in _kBlockedPatterns) {
    if (blocked.pattern.hasMatch(command)) return blocked.reason;
  }
  return null;
}
