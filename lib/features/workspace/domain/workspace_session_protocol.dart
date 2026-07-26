// 长驻会话里跑一条命令的「哨兵标记」协议（纯 Dart，可单测）。
//
// PTY 是合并流（stdout+stderr+回显），无法像一次性 exec 那样拿到干净的退出码。
// 做法与 tmux 类 Agent 一致：命令包进 `{ … }` 命令组、同一命令列表末尾
// 接 printf 哨兵，输出里扫到
// `__AETHER_DONE_<nonce>_<exitCode>__` 即认为该命令结束。

/// 组装发往长驻 shell 的输入：[command] 包进 `{ …\n}` 命令组，同一条
/// 命令列表末尾接带 [nonce] 的哨兵 printf（携带 `$?`）。[command] 可多行；
/// `$?` 取命令组内最后一条命令的退出码。
///
/// 哨兵必须和命令在同一次解析中被 shell 读完：若把哨兵单独放在下一行，
/// 命令自身读 stdin 时（`cat > f`、REPL、TUI）哨兵行会被它当输入吃掉：
/// 既污染数据（哨兵写进文件）又永远等不到结束信号。包进命令组后
/// 整段输入由 shell 解析器一次读完，stdin 里不再残留待处理行。
/// [splitStderr]（仅适合非交互命令）：命令组的 stderr 重定向到临时
/// 文件，命令结束后先打 `__AETHER_ERR_<nonce>__` 分隔标记、再 cat 回来，
/// 最后才是 DONE 哨兵——PTY 合流下唯一能把 stdout/stderr 分开的办法。
/// 交互程序的 UI 往往写 stderr，分流后提示看不到，故不默认开。
String buildSentinelInput(
  String command,
  String nonce, {
  bool splitStderr = false,
}) {
  final trimmed = command.trimRight();
  if (!splitStderr) {
    return '{\n$trimmed\n}; printf \'\\n__AETHER_DONE_${nonce}_%s__\\n\' "\$?"\n';
  }
  final err = '/tmp/.aether_stderr_$nonce';
  return '{\n$trimmed\n} 2>"$err"; __aec=\$?; '
      'printf \'\\n__AETHER_ERR_${nonce}__\\n\'; '
      'cat "$err" 2>/dev/null; rm -f "$err"; '
      'printf \'\\n__AETHER_DONE_${nonce}_%s__\\n\' "\$__aec"\n';
}

/// 在 [output] 中扫描 [nonce] 对应的哨兵。命中时返回哨兵前的输出与退出码；
/// 未命中返回 null（命令仍在跑）。
///
/// PTY 会回显输入，因此 [output] 里也含 printf 哨兵行本身的回显——回显里的
/// 哨兵字面量不带真实退出码（是 `%s__' "$?"` 原文），不会被误匹配。
///
/// 传 [command] 时会把回显噪音从结果里剥掉：回显的命令行、哨兵 printf 行
/// 以及提示符空行，只留命令的真正输出（终端页看到的原始流不受影响）。
SentinelMatch? matchSentinel(String output, String nonce, {String? command}) {
  final marker = RegExp('__AETHER_DONE_${RegExp.escape(nonce)}_(-?\\d+)__');
  final match = marker.firstMatch(output);
  if (match == null) return null;
  var head = output.substring(0, match.start);
  // splitStderr 模式：ERR 标记之后、DONE 之前是回读的 stderr。
  // 只认真正独占一行的标记（printf 输出），回显里的字面量夹在
  // 长命令行中不会命中。
  String? stderr;
  final errMarker = RegExp(
    '^__AETHER_ERR_${RegExp.escape(nonce)}__\\r?\$',
    multiLine: true,
  ).firstMatch(head);
  if (errMarker != null) {
    stderr = head.substring(errMarker.end).trim();
    head = head.substring(0, errMarker.start);
  }
  if (command != null) head = stripSessionEcho(head, command, nonce);
  // 去掉哨兵行行首残留（printf 输出前置的 \n 已计入 head 尾部）。
  head = head.trimRight();
  return SentinelMatch(
    output: head,
    exitCode: int.parse(match.group(1)!),
    stderr: stderr,
  );
}

/// 提示符前缀：busybox 默认 `# ` / `$ `，或注入 PS1 后的
/// `[名字]:路径 # `（可能带 ANSI 颜色序列）。ESC 只允许由颜色序列
/// 分支消费（普通字符分支排除 `\x1b`）：两个分支无歧义，否则每个
/// 颜色序列都有两种匹配方式，不命中的彩色长行（如 git log 输出）会
/// 灾难性回溯，卡死主线程。
final RegExp _promptPrefix = RegExp(r'^(\x1b\[[0-9;]*m|[^\n\x1b])*?[#$] ');

/// 从 [head] 里剥掉 PTY 回显噪音：与输入行（命令各行 + 哨兵 printf 行）
/// 相同的行（可带提示符前缀），以及只剩提示符的行。
String stripSessionEcho(String head, String command, String nonce) {
  final err = '/tmp/.aether_stderr_$nonce';
  final echoes = <String>{
    for (final l in command.trimRight().split('\n')) l.trimRight(),
    '{',
    '}; printf \'\\n__AETHER_DONE_${nonce}_%s__\\n\' "\$?"',
    // splitStderr 模式的尾行回显。
    '} 2>"$err"; __aec=\$?; '
        'printf \'\\n__AETHER_ERR_${nonce}__\\n\'; '
        'cat "$err" 2>/dev/null; rm -f "$err"; '
        'printf \'\\n__AETHER_DONE_${nonce}_%s__\\n\' "\$__aec"',
    // 旧协议（哨兵单独一行）的回显，兼容历史缓冲。
    'printf \'\\n__AETHER_DONE_${nonce}_%s__\\n\' "\$?"',
  }..remove('');
  final kept = <String>[];
  for (final line in head.split('\n')) {
    final t = line.trimRight();
    // 命令组跨行时 shell 用 PS2（`> `）提示续行，先剥掉再比对回显。
    final noPs2 = t.replaceFirst(RegExp(r'^(> )+'), '').trimRight();
    final noPrompt = t.replaceFirst(_promptPrefix, '').trimRight();
    // 提示符行尾的空格可能已被 trimRight 掉，补一个再探测。
    final probe = '$t ';
    final promptOnly =
        t.isNotEmpty &&
        _promptPrefix.hasMatch(probe) &&
        probe.replaceFirst(_promptPrefix, '').trim().isEmpty;
    final ps2Only = t.isNotEmpty && RegExp(r'^(> )*>?\s*$').hasMatch(t);
    if (echoes.contains(t) ||
        echoes.contains(noPs2) ||
        echoes.contains(noPrompt) ||
        promptOnly ||
        ps2Only) {
      continue;
    }
    kept.add(line);
  }
  return kept.join('\n');
}

/// 逐块过滤 PTY 显示流里的哨兵噪音（终端页联动视图 / 回看缓冲用）：
/// 丢掉所有含 `__AETHER_` 标记（DONE 哨兵 / ERR 分隔）的行——哨兵
/// 结果行和回显的 printf 行都会命中。
/// 块可能在行中间截断：若未完行有成为哨兵行的可能（已含标记、或行尾是
/// 标记的前缀），先扣住等下一块再判；否则立即放行（提示符等无换行内容
/// 不能卡住不显示）。
class SentinelDisplayFilter {
  static const String _marker = '__AETHER_';

  /// 无换行的未完行最多扣多久：超过即放行，防止异常长行永久卡住。
  static const int _holdLimit = 4096;

  String _pending = '';

  /// 喂入一块原始输出，返回应显示的部分。
  String feed(String chunk) {
    final text = _pending + chunk;
    _pending = '';
    final out = StringBuffer();
    var start = 0;
    while (true) {
      final nl = text.indexOf('\n', start);
      if (nl < 0) break;
      final line = text.substring(start, nl + 1);
      if (!line.contains(_marker)) out.write(line);
      start = nl + 1;
    }
    final tail = text.substring(start);
    if (_shouldHold(tail)) {
      _pending = tail;
    } else {
      out.write(tail);
    }
    return out.toString();
  }

  static bool _shouldHold(String tail) {
    if (tail.isEmpty || tail.length > _holdLimit) return false;
    if (tail.contains(_marker)) return true;
    final max = _marker.length - 1;
    for (var i = max < tail.length ? max : tail.length; i > 0; i--) {
      if (tail.endsWith(_marker.substring(0, i))) return true;
    }
    return false;
  }
}

/// 内置终端会话的初始化命令：提示符显示当前路径，清屏后打印工作区信息横幅
/// （clear 顺便抹掉前面注入命令的回显）。用户终端 tab 和 AI 长驻会话共用，
/// 两边看到的提示符 / 横幅一致。Alpine 的 busybox ash 编译时关掉了
/// ASH_EXPAND_PRMT，PS1 里的 bash 风格转义（\e / \w）和 `$PWD` 都不会展开，
/// 所以颜色用真实 ESC 字节、路径靠包一层 cd 在每次切目录时重算 PS1。
String buildProotGreeting({required String name, required String root}) {
  String q(String s) => s.replaceAll("'", r"'\''");
  final qName = q(name);
  final qRoot = q(root);
  return "_aether_name='$qName'; "
      '_aether_ps1() { PS1="\x1b[1;32m[\${_aether_name}]\x1b[0m:\x1b[1;34m\${PWD}\x1b[0m # "; }; '
      'cd() { command cd "\$@" && _aether_ps1; }; _aether_ps1; clear; '
      "printf '\\e[1;36mAetherlink 内置终端\\e[0m · Alpine Linux\\n"
      "工作区: \\e[1m$qName\\e[0m\\n目录: $qRoot\\n\\n'\n";
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

/// AI 长驻会话的非交互环境（对标 CC：GIT_TERMINAL_PROMPT=0 / GIT_ASKPASS=''
/// / GIT_EDITOR=true 让 git 要凭据、要编辑器时快速失败而不是挂住等输入；
/// pager 全部走 cat 防分页卡住；apt/dpkg 走非交互前端）。
/// 只注给 AI 工具的会话，用户自己的终端 tab 不受影响。
const Map<String, String> kAgentNonInteractiveEnv = {
  'GIT_TERMINAL_PROMPT': '0',
  'GIT_ASKPASS': '',
  'SSH_ASKPASS': '',
  'GIT_EDITOR': 'true',
  'GIT_PAGER': 'cat',
  'PAGER': 'cat',
  'SYSTEMD_PAGER': 'cat',
  'LESS': 'FRX',
  'DEBIAN_FRONTEND': 'noninteractive',
};

/// ANSI CSI/OSC 序列（剥掉后再做交互提示匹配，PTY 输出常带颜色/光标控制）。
final RegExp _ansiSeq = RegExp(r'\x1b\[[0-9;?]*[a-zA-Z]|\x1b\][^\x07]*\x07');

/// 常见交互提示模式（保守白名单，配合「输出静默」双条件判定，误报代价是
/// 提前把控制权还给模型——模型看输出不像在等输入可以继续等）：
/// y/n 确认、密码/用户名/token 输入、continue 确认、行尾问号、
/// 中文的「是否/请输入/请选择」、交互式选择器（❯）。
final List<RegExp> _interactivePromptPatterns = [
  RegExp(r'\[[yY]/[nN]\]|\((?:y/n|yes/no)\)', caseSensitive: false),
  RegExp(
    r"(password|passphrase|username|login|token|passcode)[^\n]*[:：]\s*$",
    caseSensitive: false,
  ),
  RegExp(r'(continue|proceed|overwrite|confirm)\?\s*$', caseSensitive: false),
  RegExp(r'(是否|请输入|请选择|请确认)'),
  RegExp(r'[?？]\s*$'),
  RegExp(r'^\s*❯', multiLine: true),
  // REPL 提示符（python `>>>` / `...`、node/irb 等裸 `>`）停在行尾。
  RegExp(r'^(>>>|\.\.\.|In \[\d*\]:)\s*$'),
  // 数字菜单 / 选项选择："Enter your choice [1-3]:" / "Select an option:"。
  RegExp(
    r'\b(choice|select|selection|option)\b[^\n]*[:：]\s*$',
    caseSensitive: false,
  ),
  // 分页器停顣（PAGER=cat 已兜底，命令自带分页时仍可能出现）。
  RegExp(r'--More--|\(END\)'),
  // 「按回车 / 任意键继续」类提示。
  RegExp(
    r'\b(press|hit)\b[^\n]*\b(enter|return|any key)\b',
    caseSensitive: false,
  ),
  // 带默认值的输入提示："Project name [my-app]:" / "Port (8080):"。
  RegExp(r'(\[[^\[\]\n]+\]|\([^()\n]+\))\s*[:：]\s*$'),
  // "Enter …:" 式输入提示。
  RegExp(r'\benter\b[^\n]*[:：]\s*$', caseSensitive: false),
];

/// [tail]（输出尾部）看起来是否停在一个交互提示上：剥 ANSI 后取最后
/// 一个非空行做模式匹配。空输出不算（静默但无提示，可能只是慢命令）。
bool looksLikeInteractivePrompt(String tail) {
  final clean = tail.replaceAll(_ansiSeq, '');
  final lines = clean.split('\n');
  String lastLine = '';
  for (var i = lines.length - 1; i >= 0; i--) {
    final t = lines[i].trimRight();
    if (t.trim().isNotEmpty) {
      lastLine = t;
      break;
    }
  }
  if (lastLine.isEmpty) return false;
  return _interactivePromptPatterns.any((p) => p.hasMatch(lastLine));
}

class SentinelMatch {
  const SentinelMatch({
    required this.output,
    required this.exitCode,
    this.stderr,
  });

  /// 哨兵之前的全部会话输出（含 PTY 回显）。
  final String output;
  final int exitCode;

  /// splitStderr 模式下回读的 stderr；普通模式（合流）为 null。
  final String? stderr;
}
