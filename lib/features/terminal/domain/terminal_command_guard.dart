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

/// 项目模式下一条命令的风险评级（双作用域设计稿 §3.2）。
///
/// - [safeInRoot]   : root 内的低危只读命令，免 HITL 审批直接放行。
/// - [needsApproval]: 默认档，走标准 HITL 审批。
/// - [escapesRoot]  : 疑似越出工作区 root，强制 HITL（硬要求，任何预授权
///                    都不覆盖，§4 需求方结论）。
enum CommandRisk { safeInRoot, needsApproval, escapesRoot }

/// root 内免审批的只读命令白名单（首个词条匹配；管道/连接的每一段都要命中）。
const Set<String> _kSafeReadOnlyCommands = {
  'ls', 'cat', 'head', 'tail', 'wc', 'pwd', 'echo', 'printf', 'stat',
  'file', 'du', 'df', 'grep', 'egrep', 'fgrep', 'rg', 'find', 'which',
  'whoami', 'id', 'env', 'printenv', 'date', 'uname', 'basename',
  'dirname', 'realpath', 'readlink', 'sort', 'uniq', 'cut', 'tr', 'diff',
  'md5sum', 'sha1sum', 'sha256sum', 'tree', 'less', 'more',
};

/// 命令里出现这些即认为可能改变作用域/身份，直接 escapesRoot。
final RegExp _kScopeEscapePattern = RegExp(
  r'(^|[\s;&|])(su|sudo|chroot|proot)\b',
);

/// 评估项目模式（scope=project）下 [command] 相对工作区 [root] 的风险。
///
/// 启发式（非强制隔离，见设计稿 §4）：解析命令里的绝对路径、`~`/`$HOME`
/// 引用与 `cd ..` 上溯，越出 [root] 即 [CommandRisk.escapesRoot]；全部
/// 词条命中只读白名单且无越界迹象时为 [CommandRisk.safeInRoot]；其余为
/// [CommandRisk.needsApproval]。管道/脚本内部藏的路径看不穿——那由黑名单
/// 与 HITL 兜底。
CommandRisk evaluateCommandRisk(String command, {required String root}) {
  final normalizedRoot = root.endsWith('/') && root != '/'
      ? root.substring(0, root.length - 1)
      : root;

  if (_kScopeEscapePattern.hasMatch(command)) return CommandRisk.escapesRoot;

  // `~` / $HOME 引用：root 本身是（或在）家目录下才算界内。
  if (RegExp(r'(^|[\s=:"' r"'])(~($|[/\s])|\$HOME\b|\$\{HOME\})")
      .hasMatch(command)) {
    return CommandRisk.escapesRoot;
  }

  // 绝对路径词条越出 root 即越界（/dev/null 这类哑设备除外）。
  for (final match
      in RegExp(r'''(^|[\s=:"'])(/[^\s;&|"')]*)''').allMatches(command)) {
    final path = match.group(2)!;
    if (path == '/dev/null') continue;
    if (!_pathInsideRoot(path, normalizedRoot)) {
      return CommandRisk.escapesRoot;
    }
  }

  // `cd`（无参回 HOME）与 `cd ..` 上溯视为越界（无法静态确认仍在 root 内）。
  for (final segment in _splitSegments(command)) {
    final words = segment.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) continue;
    if (words.first == 'cd') {
      if (words.length == 1) return CommandRisk.escapesRoot;
      final target = words[1];
      if (target == '-' || target.split('/').contains('..')) {
        return CommandRisk.escapesRoot;
      }
    }
    if (words.any((w) => w.split('/').contains('..'))) {
      return CommandRisk.escapesRoot;
    }
  }

  if (isReadOnlyCommand(command)) return CommandRisk.safeInRoot;

  return CommandRisk.needsApproval;
}

/// [command] 是否为纯只读：每个管道/连接段的首词都命中只读白名单，
/// 且无重定向、无 su/sudo/chroot/proot 提权、无 find -delete / -exec /
/// sort -o 等会写或执行任意命令的旗标。只读命令在 rootfs 沙箱内无
/// 副作用，AI 通道可免 HITL 审批直接放行。
bool isReadOnlyCommand(String command) {
  if (_kScopeEscapePattern.hasMatch(command)) return false;
  final segments =
      _splitSegments(command).toList(growable: false);
  if (segments.isEmpty) return false;
  final allSafe = segments.every((segment) {
    final words = segment.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return false;
    return _kSafeReadOnlyCommands.contains(words.first);
  });
  // 重定向会写文件；find -delete / -exec / -ok、sort -o 等旗标会写或执行
  // 任意命令，同样不算只读。
  return allSafe &&
      !command.contains('>') &&
      !RegExp(r'\s-(delete|exec|execdir|ok|okdir|o)\b').hasMatch(command);
}

bool _pathInsideRoot(String path, String root) {
  if (root == '/') return true;
  return path == root || path.startsWith('$root/');
}

/// 按 `;` `&&` `||` `|` `&` 切分为子命令段。
Iterable<String> _splitSegments(String command) =>
    command.split(RegExp(r'\|\||&&|[;|&\n]')).where((s) => s.trim().isNotEmpty);
