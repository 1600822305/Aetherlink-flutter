// 工作区长驻会话池 — 内置终端的会话池抽象（exec 超时后台继续跑 +
// tailOutput 回看）上移到 WorkspaceBackend 层：任何 canExec 的后端（内置
// 终端 / SSH / Termux）都能开长驻 shell 会话，AI 工具（@aether/terminal 的
// terminal_session_*）据此在远端也能跑后台长任务。
//
// 交互式终端页不走这里（那是用户自己的会话，生命周期由页面管理）。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_session_protocol.dart';

part 'workspace_session_pool.g.dart';

/// 会话空闲多久后自动释放进程（无任务 N 分钟后自动释放）。
const Duration kSessionIdleTimeout = Duration(minutes: 10);

/// 单个工作区池内、每类创建者（AI / 用户）各自的并发会话上限：
/// AI 跑满长任务不会挤占用户「新建会话」的名额，反之亦然。
const int kMaxPooledSessions = 4;

/// 无终端视图接入时会话 PTY 的默认尺寸；接入视图后按视图实际尺寸同步。
const int kDefaultSessionColumns = 200;
const int kDefaultSessionRows = 50;

/// 用户键入半行后多久仍视为占用会话；超过后视为遗留半行，由 Ctrl-U 兜底清掉。
const Duration kUserTypingHold = Duration(seconds: 30);

/// 单个会话保留的输出回看缓冲上限（字符）。
const int kSessionBufferLimit = 200 * 1024;

/// exec 期间输出静默多久后才尝试判定「在等交互输入」：静默 +
/// 尾部像交互提示双条件同时满足才提前返回，避免把慢命令误判。
const Duration kInteractiveSilenceThreshold = Duration(seconds: 10);

/// 静默检测的轮询周期。
const Duration kInteractiveCheckInterval = Duration(seconds: 2);

/// 中断（Ctrl-C）后等 shell 回到提示符的上限：期间会话保持 busy，
/// 避免下一条命令被仍在收尾的旧进程（如 npm install）当 stdin 吃掉。
const Duration kInterruptSettleTimeout = Duration(seconds: 2);

/// 工作区后端配置指纹：这些字段任一变化，旧会话就跑在错误的地方。
/// 名称不算（改名不应杀会话）。
String workspaceConfigKey({
  required String backendType,
  required String root,
  String? connectionId,
  String? scope,
  bool isolatedHome = false,
}) => '$backendType|${connectionId ?? ''}|$root|${scope ?? ''}|$isolatedHome';

/// 会话创建者：AI 工具建的会话 vs 用户在工作台 / 终端页手动新建的会话。
/// AI 不指定 session 时只复用自己的会话，不会闯进用户的会话。
enum SessionOwner { ai, user }

/// Thrown by session operations with a user-facing message.
class WorkspaceSessionException implements Exception {
  const WorkspaceSessionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 在长驻会话里跑一条命令的结果。输出为 PTY 合并流（stdout+stderr+回显）。
class WorkspaceSessionExecResult {
  const WorkspaceSessionExecResult({
    required this.output,
    required this.exitCode,
    this.timedOut = false,
    this.canceled = false,
    this.waitingInput = false,
    this.background = false,
    this.fullScreen = false,
    this.stderr,
  });

  final String output;

  /// 命令退出码；超时 / 被中断（命令可能仍在收尾）时为 null。
  final int? exitCode;
  final bool timedOut;

  /// 用户点了中断：已向会话发 Ctrl-C（SIGINT），会话本身仍存活。
  final bool canceled;

  /// 命令疑似在等交互输入（自动检测或用户手动标记）：命令未结束、
  /// 仍在前台跑，可用 [PooledWorkspaceSession.writeInput] 写 stdin 回答。
  final bool waitingInput;

  /// 主动后台执行：命令已提交到会话里跑，调用立即返回（不等结果），
  /// 结束后退出码可由 [PooledWorkspaceSession.lastExitCode] 查到。
  final bool background;

  /// 等交互的原因是前台跑着全屏 TUI（仍在备用屏），需按键退出该程序。
  final bool fullScreen;

  /// splitStderr 模式下分流出的 stderr；合流模式为 null。
  final String? stderr;
}

/// exec 被用户中断（Ctrl-C 已发出）时的内部信号，用于跳出等哨兵的 await。
class _SessionExecCanceled implements Exception {
  const _SessionExecCanceled();
}

/// exec 被判定为在等交互输入（自动检测 / 用户手动标记）时的内部信号：
/// 提前把已有输出还给调用方，命令继续在前台跑。
class _SessionExecWaitingInput implements Exception {
  const _SessionExecWaitingInput();
}

/// 池内一个长驻 shell 会话。
class PooledWorkspaceSession {
  PooledWorkspaceSession._({
    required this.id,
    required this.name,
    required this.workspaceLabel,
    required this.workspaceId,
    required WorkspaceShellSession shell,
    this.owner = SessionOwner.ai,
  }) : _shell = shell,
       createdAt = DateTime.now(),
       lastUsedAt = DateTime.now() {
    // cast 到 List<int>：Utf8Decoder 的 StreamTransformer 反化是
    // <List<int>, String>，Stream<Uint8List>.transform 在运行时泛型检查下
    // 会直接抛 type error。
    _outputSub = shell.output
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(_append);
    shell.done.whenComplete(() => _alive = false);
  }

  final String id;
  final String name;

  /// 会话所属工作区的展示名（内置终端会话为「内置终端」）。
  final String workspaceLabel;

  /// 会话所属工作区的 ID；未锚定工作区（裸后端默认池）时为 null。
  /// 双作用域设计稿 §3.1：会话按工作区隔离的过滤键。
  final String? workspaceId;

  /// 会话创建者（见 [SessionOwner]）。
  final SessionOwner owner;

  final DateTime createdAt;
  DateTime lastUsedAt;

  /// 当前接入的终端视图数（工作台 tab / 终端页）。>0 时空闲回收跳过它：
  /// 用户开着视图围观时会话不该被 10 分钟回收掉。
  int _viewers = 0;
  bool get hasViewers => _viewers > 0;

  /// 终端视图接入 / 断开时调用（见 SessionTerminalAttachment）。
  void addViewer() {
    _viewers++;
    lastUsedAt = DateTime.now();
  }

  void removeViewer() {
    if (_viewers > 0) _viewers--;
    // 视图关闭重新计时，不因围观期间未输入而立刻被回收。
    lastUsedAt = DateTime.now();
  }

  final WorkspaceShellSession _shell;
  StreamSubscription<String>? _outputSub;
  final StringBuffer _buffer = StringBuffer();
  final SentinelDisplayFilter _displayFilter = SentinelDisplayFilter();

  /// 显示流：已滤掉哨兵行，供终端页联动 / 回看缓冲。
  final StreamController<String> _chunks = StreamController<String>.broadcast();

  /// 原始流：含哨兵行，供 exec 扫哨兵判定命令结束。
  final StreamController<String> _raw = StreamController<String>.broadcast();
  bool _alive = true;

  /// busy 变化可监听（终端页的 AI 会话状态条据此实时刷新）。
  final ValueNotifier<bool> busyListenable = ValueNotifier<bool>(false);

  bool get alive => _alive;
  bool get busy => busyListenable.value;
  set _busy(bool value) => busyListenable.value = value;

  /// 最近一条已结束命令的退出码（含超时/后台提交后才结束的）；
  /// 从未跑完过命令时为 null。配合 busy 可查后台命令是否结束。
  int? lastExitCode;

  /// 回看缓冲开头在全量输出流中的偏移（截断丢弃的部分），
  /// 用于增量游标：cursor = _streamBase + 缓冲长度，单调递增。
  int _streamBase = 0;

  /// 当前输出流游标；下次用 [outputSince] 传回可只取新增输出。
  int get outputCursor => _streamBase + _buffer.length;

  /// 用户在提示符下键入了未回车的半行（不含 AI 命令运行期间写进 stdin 的输入）。
  bool _hasPendingUserLine = false;
  DateTime _lastUserInputAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 用户正在提示符下键入（半行未回车）：此时 AI 命令会与半行拼接，exec 拒绝执行。
  bool get isUserTyping =>
      _hasPendingUserLine &&
      DateTime.now().difference(_lastUserInputAt) < kUserTypingHold;

  int _columns = kDefaultSessionColumns;
  int _rows = kDefaultSessionRows;

  /// 当前 exec 的「标记为等交互」触发器；无 exec 在等时为 null。
  void Function()? _flagWaitingInput;

  /// 当前 exec 的「会话被关闭」触发器：会话 close 时让正在等哨兵的
  /// exec（含超时后的后台等待）立即出错返回，不永久悬挂。
  void Function()? _failPendingExec;

  /// 当前 exec 的「已发 Ctrl-C」触发器：交互式 shell 收到 SIGINT 会放弃
  /// 整个命令列表，哨兵不会再打印；不在此收尾的话会话会永久 busy，
  /// 后续命令全部被拒。
  void Function()? _cancelPendingExec;

  /// 手动标记当前前台命令在等交互输入（自动检测漏网时的用户兜底）：
  /// 正在等哨兵的 exec 立即带已有输出提前返回（waitingInput = true），
  /// 命令继续在会话里跑。没有正在等的 exec 时返回 false。
  bool markWaitingInput() {
    final flag = _flagWaitingInput;
    if (flag == null) return false;
    flag();
    return true;
  }

  /// 实时输出流（PTY 合并流，含 ANSI 序列，已滤掉哨兵行），供终端页联动渲染。
  Stream<String> get chunks => _chunks.stream;

  /// 当前回看缓冲的全量快照（含 ANSI 序列），供终端页接入时回放历史。
  String snapshot() => _buffer.toString();

  /// 回看缓冲的尾部 [tail] 个字符。
  String tailOutput([int tail = 4000]) {
    final text = _buffer.toString();
    return text.length <= tail ? text : text.substring(text.length - tail);
  }

  /// 自游标 [since]（上次返回的 [outputCursor]）以来的新增输出。
  /// [since] 早于缓冲开头（头部已被截断丢弃）时从缓冲开头返。
  ({String output, int cursor}) outputSince(int since) {
    final text = _buffer.toString();
    final cursor = _streamBase + text.length;
    final start = (since - _streamBase).clamp(0, text.length);
    return (output: text.substring(start), cursor: cursor);
  }

  /// 向会话发 Ctrl-C（SIGINT）中断当前前台命令，会话本身保活。
  /// 命令响应 SIGINT 退出后 shell 回到提示符，哨兵（若仍在同一命令
  /// 列表里）会随之打印，busy 自然释放。
  void interrupt() {
    if (!_alive) {
      throw const WorkspaceSessionException('会话已结束');
    }
    lastUsedAt = DateTime.now();
    _shell.write(const [0x03]);
    _cancelPendingExec?.call();
  }

  void _append(String chunk) {
    if (!_raw.isClosed) _raw.add(chunk);
    final visible = _displayFilter.feed(chunk);
    if (visible.isEmpty) return;
    _buffer.write(visible);
    if (_buffer.length > kSessionBufferLimit) {
      final text = _buffer.toString();
      // 从行边界开始保留，避免从半个 ANSI 序列 / 多字节字符中间切开
      // 导致回放渲染错乱；并插入截断标记让回看方知道头部已丢。
      var cut = text.length - kSessionBufferLimit ~/ 2;
      final nl = text.indexOf('\n', cut);
      if (nl >= 0 && nl + 1 < text.length) cut = nl + 1;
      const marker = '…（缓冲已截断，更早输出已丢弃）\r\n';
      // 截掉 cut 个、补进 marker.length 个：基偏移同步调整，
      // 保证 outputCursor 截断前后连续。
      _streamBase += cut - marker.length;
      _buffer
        ..clear()
        ..write(marker)
        ..write(text.substring(cut));
    }
    if (!_chunks.isClosed) _chunks.add(visible);
  }

  /// 在本会话里跑 [command]，等哨兵回来或超时。超时不杀会话——命令继续在
  /// 后台跑，之后可用 [tailOutput] 回看。[onOutput] 提供时每到一块输出即
  /// 回调（实时输出）；[cancelSignal] 完成时向会话发 Ctrl-C 中断当前命令
  /// （会话保活），结果 `canceled = true`。
  ///
  /// [background] 为 true 时命令提交后立即返回（background = true，
  /// 不等结果），会话保持 busy 直到哨兵回来；结果通过 [outputSince] /
  /// [tailOutput] 回看，退出码落在 [lastExitCode]。
  ///
  /// [splitStderr] 为 true 时（仅适合非交互命令）stderr 分流到结果的
  /// stderr 字段，见 [buildSentinelInput]。
  Future<WorkspaceSessionExecResult> exec(
    String command, {
    Duration timeout = const Duration(seconds: 120),
    Future<void>? cancelSignal,
    void Function(String chunk)? onOutput,
    bool background = false,
    bool splitStderr = false,
  }) async {
    if (!_alive) {
      throw const WorkspaceSessionException('会话已结束，请新建会话');
    }
    if (busy) {
      throw const WorkspaceSessionException(
        '会话正忙（上一条命令还没结束）：用 terminal_session action=output 看它'
        '是否在等输入，action=interrupt 中断它，或不传 session / 换新的 session '
        '名字执行',
      );
    }
    if (isUserTyping) {
      throw const WorkspaceSessionException(
        '用户正在该会话终端里键入（有未回车的输入），为避免与命令拼接已拒绝执行；可换一个会话或稍后再试',
      );
    }
    _busy = true;
    lastUsedAt = DateTime.now();
    lastExitCode = null;
    final nonce = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final collected = StringBuffer();
    final done = Completer<SentinelMatch>();
    // 哨兵总在输出末尾：先在「上一块尾部 + 新块」的小窗口里做廉价预检，
    // 命中才对全量输出跑 matchSentinel，避免长输出下逐块全量重扫（O(n²)）。
    var windowTail = '';
    var settled = false;
    var canceled = false;
    var releaseInFinally = true;
    var lastChunkAt = DateTime.now();
    final startedAt = DateTime.now();
    var altScreen = false;
    var fullScreen = false;
    _flagWaitingInput = () {
      if (settled || done.isCompleted) return;
      done.completeError(const _SessionExecWaitingInput());
    };
    _failPendingExec = () {
      if (done.isCompleted) return;
      done.completeError(const WorkspaceSessionException('会话已关闭，命令结果不可得'));
    };
    _cancelPendingExec = () {
      if (done.isCompleted) return;
      canceled = true;
      done.completeError(const _SessionExecCanceled());
    };
    // 自动判定：输出静默超阈 + 尾部像交互提示 → 不等满超时，提前把
    // 控制权和已有输出还给调用方（模型可立刻写 stdin 回答）。
    final silenceTimer = Timer.periodic(kInteractiveCheckInterval, (_) {
      if (settled || done.isCompleted) return;
      if (altScreen &&
          DateTime.now().difference(startedAt) >=
              kInteractiveSilenceThreshold) {
        fullScreen = true;
        _flagWaitingInput?.call();
        return;
      }
      if (DateTime.now().difference(lastChunkAt) <
          kInteractiveSilenceThreshold) {
        return;
      }
      final text = collected.toString();
      final tail = text.length <= 800
          ? text
          : text.substring(text.length - 800);
      if (looksLikeInteractivePrompt(stripSessionEcho(tail, command, nonce))) {
        _flagWaitingInput?.call();
      }
    });
    if (cancelSignal != null) {
      unawaited(
        cancelSignal.then((_) {
          if (settled) return;
          // Ctrl-C 中断前台命令；shell 回到提示符后哨兵行不会再来，
          // 直接以当前已收集的输出收尾。
          _shell.write(utf8.encode('\x03'));
          _cancelPendingExec?.call();
        }),
      );
    }
    unawaited(
      done.future.then((m) => lastExitCode = m.exitCode, onError: (_) {}),
    );
    final sub = _raw.stream.listen((chunk) {
      collected.write(chunk);
      lastChunkAt = DateTime.now();
      // 超时 / 等交互提前返回后监听仍在（等哨兵释放 busy），但工具结果
      // 已返回，不再向已完成的工具卡片回调实时输出。
      if (!settled) onOutput?.call(chunk);
      final window = windowTail + chunk;
      windowTail = window.length <= 96
          ? window
          : window.substring(window.length - 96);
      final toggle = lastAlternateScreenToggle(window);
      if (toggle != null) altScreen = toggle;
      if (!window.contains('__AETHER_DONE_$nonce')) return;
      final match = matchSentinel(
        collected.toString(),
        nonce,
        command: command,
      );
      if (match != null && !done.isCompleted) done.complete(match);
    });
    var released = false;
    void releaseNow() {
      if (released) return;
      released = true;
      _busy = false;
      lastUsedAt = DateTime.now();
      _failPendingExec = null;
      _cancelPendingExec = null;
      sub.cancel();
    }

    // 被中断时先等 shell 回到提示符（探针哨兵回来或超时）再释放 busy。
    void release() {
      if (canceled && _alive) {
        unawaited(_settleAfterInterrupt().whenComplete(releaseNow));
      } else {
        releaseNow();
      }
    }

    try {
      _hasPendingUserLine = false;
      // Ctrl-E 先移到行尾再 Ctrl-U：Ctrl-U 只删光标前内容，用户把光标
      // 移到行中留下的半行尾巴会拼进命令。
      _shell.write(const [0x05, 0x15]);
      _shell.write(
        utf8.encode(
          buildSentinelInput(command, nonce, splitStderr: splitStderr),
        ),
      );
      if (background) {
        // 主动后台：不等哨兵，保持 busy，后台等哨兵回来才释放。
        releaseInFinally = false;
        unawaited(
          done.future.then<void>((_) {}, onError: (_) {}).whenComplete(release),
        );
        return const WorkspaceSessionExecResult(
          output: '',
          exitCode: null,
          background: true,
        );
      }
      final match = await done.future.timeout(timeout);
      return WorkspaceSessionExecResult(
        output: match.output,
        exitCode: match.exitCode,
        stderr: match.stderr,
      );
    } on TimeoutException {
      // 命令还在前台跑：保持 busy，后台等哨兵回来才释放。否则池会把
      // 前台被占用的会话当空闲复用，新命令被旧进程当 stdin 吃掉。
      releaseInFinally = false;
      unawaited(
        done.future.then<void>((_) {}, onError: (_) {}).whenComplete(release),
      );
      return WorkspaceSessionExecResult(
        output: stripSessionEcho(collected.toString(), command, nonce),
        exitCode: null,
        timedOut: true,
        canceled: canceled,
      );
    } on _SessionExecCanceled {
      releaseInFinally = false;
      release();
      return WorkspaceSessionExecResult(
        output: stripSessionEcho(collected.toString(), command, nonce),
        exitCode: null,
        canceled: true,
      );
    } on _SessionExecWaitingInput {
      // 命令还在前台等输入：与超时同样保持 busy，后台等哨兵回来才释放。
      releaseInFinally = false;
      unawaited(
        done.future.then<void>((_) {}, onError: (_) {}).whenComplete(release),
      );
      return WorkspaceSessionExecResult(
        output: stripSessionEcho(collected.toString(), command, nonce),
        exitCode: null,
        waitingInput: true,
        fullScreen: fullScreen,
      );
    } finally {
      settled = true;
      silenceTimer.cancel();
      _flagWaitingInput = null;
      if (releaseInFinally) {
        _failPendingExec = null;
        _cancelPendingExec = null;
        _busy = false;
        lastUsedAt = DateTime.now();
        await sub.cancel();
      }
    }
  }

  /// 中断后的收尾：写一条空命令探针哨兵，等它带真实退出码回来（说明 shell
  /// 已回到提示符、旧进程已退出），最多等 [kInterruptSettleTimeout]。
  /// 探针若被仍在跑的程序读走也无害：超时后照常释放。
  Future<void> _settleAfterInterrupt() async {
    if (!_alive || _raw.isClosed) return;
    final nonce = 'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    // 回显里的哨兵是 `%s__` 原文，只认带数字退出码的真实哨兵。
    final marker = RegExp('__AETHER_DONE_${nonce}_\\d+__');
    final seen = Completer<void>();
    var window = '';
    final sub = _raw.stream.listen((chunk) {
      window += chunk;
      if (window.length > 512) window = window.substring(window.length - 512);
      if (!seen.isCompleted && marker.hasMatch(window)) seen.complete();
    });
    try {
      _shell.write(utf8.encode(buildSentinelInput(':', nonce)));
      await seen.future.timeout(kInterruptSettleTimeout, onTimeout: () {});
    } catch (_) {
      // 会话已关闭等：直接释放。
    } finally {
      await sub.cancel();
    }
  }

  /// 往会话的运行中进程写 stdin（交互式程序输入，设计稿 §3.4）。
  /// 不自动追加换行，需要回车确认时由调用方在 [data] 末尾带 `\n`。
  /// 含 Ctrl-C 时按中断处理，收尾正在等哨兵的 exec（见 [interrupt]）。
  void writeInput(String data) {
    if (!_alive) {
      throw const WorkspaceSessionException('会话已结束，请新建会话');
    }
    lastUsedAt = DateTime.now();
    _shell.write(utf8.encode(data));
    if (data.contains('\x03')) _cancelPendingExec?.call();
  }

  /// 用户在终端视图里的键入：同 [writeInput]，另外记录提示符下是否留有
  /// 未回车的半行，供 [isUserTyping] 判定占用。
  void writeUserInput(String data) {
    writeInput(data);
    if (busy || data.isEmpty) return;
    _lastUserInputAt = DateTime.now();
    final lineEnd = data.lastIndexOf(RegExp('[\r\n\x03\x15]'));
    _hasPendingUserLine = lineEnd < data.length - 1;
  }

  /// 同步 PTY 窗口尺寸（终端视图布局变化时调用）；尺寸未变或会话已结束时忽略。
  void resize(int columns, int rows) {
    if (!_alive || columns <= 0 || rows <= 0) return;
    if (columns == _columns && rows == _rows) return;
    _columns = columns;
    _rows = rows;
    _shell.resize(columns, rows);
  }

  Future<void> close() async {
    _alive = false;
    // 让正在等哨兵的 exec（含超时后的后台等待）立即出错返回，
    // 避免调用方永久悬挂 / 监听器泄漏。
    _failPendingExec?.call();
    _failPendingExec = null;
    await _outputSub?.cancel();
    _outputSub = null;
    if (!_chunks.isClosed) await _chunks.close();
    if (!_raw.isClosed) await _raw.close();
    await _shell.close();
  }
}

/// 单个后端的长驻会话池：新建 / 列出 / 关闭 / 复用默认会话，空闲超时自动回收。
class WorkspaceSessionPool {
  WorkspaceSessionPool(
    this._backend, {
    required String Function() nextId,
    this.workspaceLabel = '',
    this.workspaceId,
    this.configKey,
    void Function()? onChanged,
  }) : _nextId = nextId,
       _onChanged = onChanged;

  final WorkspaceBackend _backend;
  final String Function() _nextId;

  /// 会话集合变化（新建 / 关闭 / 回收）时通知，供终端页联动刷新。
  final void Function()? _onChanged;

  /// 池所属工作区的展示名，赋给新建的会话（工作区改名后由管理器更新）。
  String workspaceLabel;

  /// 建池时工作区的后端配置指纹（类型 / 连接 / 根目录 / 作用域 / 独立 HOME）。
  /// 管理器发现指纹变了就关掉旧池重建，避免改了 SSH 主机或根目录后
  /// 命令仍跑在旧地方。
  final String? configKey;

  /// 池所属工作区的 ID（双作用域设计稿 §3.1）；裸后端默认池为 null。
  final String? workspaceId;

  /// 池对应的后端（管理器按后端类型批量关会话用，如清理内置终端）。
  WorkspaceBackend get backend => _backend;

  final Map<String, PooledWorkspaceSession> _sessions = {};
  Timer? _reaper;

  List<PooledWorkspaceSession> list() {
    _prune();
    return _sessions.values.toList();
  }

  PooledWorkspaceSession? find(String id) {
    _prune();
    return _sessions[id];
  }

  /// [greeting] 非空时在环境注入后写入（内置终端的 PS1 + 横幅，与用户
  /// 终端 tab 一致，终端页联动围观时观感相同）。
  Future<PooledWorkspaceSession> create({
    String? name,
    String? workingDirectory,
    Map<String, String> environment = const {},
    String? greeting,
    SessionOwner owner = SessionOwner.ai,
  }) async {
    _prune();
    final sameOwner = _sessions.values.where((s) => s.owner == owner).length;
    if (sameOwner >= kMaxPooledSessions) {
      throw WorkspaceSessionException(
        owner == SessionOwner.user
            ? '手动会话已达上限（$kMaxPooledSessions 个）：先关掉不用的会话'
            : 'AI 会话数已达上限（$kMaxPooledSessions 个）：可用 terminal_session '
                  'action=close 关掉不用的会话，或 action=interrupt 中断卡住的命令',
      );
    }
    final shell = await _backend.startShell(
      columns: kDefaultSessionColumns,
      rows: kDefaultSessionRows,
      workingDirectory: workingDirectory,
    );
    if (environment.isNotEmpty) {
      shell.write(utf8.encode(buildSessionEnvSetup(environment)));
    }
    if (greeting != null && greeting.isNotEmpty) {
      shell.write(utf8.encode(greeting));
    }
    final id = _nextId();
    final session = PooledWorkspaceSession._(
      id: id,
      name: (name == null || name.trim().isEmpty) ? id : name.trim(),
      workspaceLabel: workspaceLabel,
      workspaceId: workspaceId,
      shell: shell,
      owner: owner,
    );
    _sessions[id] = session;
    _ensureReaper();
    _onChanged?.call();
    return session;
  }

  /// 取默认长驻会话（第一个空闲的 AI 会话），没有就新建——「默认保留 1 个
  /// 长驻 shell，毫秒级复用」。跳过用户手动新建的会话（cwd / 环境是用户的
  /// 调试现场）和用户正在键入半行的会话（否则 exec 必然被拒）。
  Future<PooledWorkspaceSession> acquireDefault({
    String? workingDirectory,
    Map<String, String> environment = const {},
    String? greeting,
  }) async {
    _prune();
    for (final session in _sessions.values) {
      if (session.owner != SessionOwner.ai) continue;
      if (session.alive && !session.busy && !session.isUserTyping) {
        return session;
      }
    }
    return create(
      workingDirectory: workingDirectory,
      environment: environment,
      greeting: greeting,
    );
  }

  Future<bool> close(String id) async {
    final session = _sessions.remove(id);
    if (session == null) return false;
    await session.close();
    if (_sessions.isEmpty) _stopReaper();
    _onChanged?.call();
    return true;
  }

  Future<void> closeAll() async {
    final sessions = _sessions.values.toList();
    _sessions.clear();
    _stopReaper();
    for (final session in sessions) {
      await session.close();
    }
  }

  /// 剔除已退出的会话。
  void _prune() {
    final before = _sessions.length;
    _sessions.removeWhere((_, s) => !s.alive);
    if (_sessions.isEmpty) _stopReaper();
    if (_sessions.length != before) _onChanged?.call();
  }

  void _ensureReaper() {
    _reaper ??= Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      final expired = _sessions.values
          .where(
            (s) =>
                !s.busy &&
                !s.hasViewers &&
                now.difference(s.lastUsedAt) > kSessionIdleTimeout,
          )
          .map((s) => s.id)
          .toList();
      for (final id in expired) {
        close(id);
      }
      _prune();
    });
  }

  void _stopReaper() {
    _reaper?.cancel();
    _reaper = null;
  }
}

/// 会话池管理器：每个工作区一个池（双作用域设计稿 §3.1：同一后端上的
/// 不同工作区各自隔离；未锚定工作区的裸后端用后端自身做键），
/// 会话 ID 全局唯一，查找 / 关闭可跨池按 ID 直达。
class WorkspaceSessionPoolManager extends ChangeNotifier {
  final Map<Object, WorkspaceSessionPool> _pools = {};
  int _nextId = 1;

  /// 本次进程启动的标识，拼进会话 ID（`s1-k3f`）：App 重启后序号从 1
  /// 重新数，不带它时历史上下文里的旧 `s2` 会静默命中新建的 `s2`
  /// （cwd / 环境都已不同）。
  final String _bootTag = (DateTime.now().microsecondsSinceEpoch % 46656)
      .toRadixString(36)
      .padLeft(3, '0');

  /// [backend] 上工作区 [workspaceId] 的会话池；首次访问时创建，
  /// [workspaceLabel] 赋给其新会话。[workspaceId] 为 null 时（未锚定
  /// 工作区的裸后端）退化为按后端实例一个池。
  ///
  /// [configKey]（见 [workspaceConfigKey]）与已有池不一致，或后端实例已换
  /// （SSH 连接改绑），则关掉旧池的全部会话并重建——配置变更后不再
  /// 把命令发到旧主机 / 旧目录。
  WorkspaceSessionPool poolFor(
    WorkspaceBackend backend, {
    String workspaceLabel = '',
    String? workspaceId,
    String? configKey,
  }) {
    final key = workspaceId ?? backend;
    final existing = _pools[key];
    if (existing != null) {
      final stale =
          !identical(existing.backend, backend) ||
          (configKey != null &&
              existing.configKey != null &&
              existing.configKey != configKey);
      if (!stale) {
        if (workspaceLabel.isNotEmpty) {
          existing.workspaceLabel = workspaceLabel;
        }
        return existing;
      }
      _pools.remove(key);
      unawaited(existing.closeAll().whenComplete(notifyListeners));
    }
    final pool = WorkspaceSessionPool(
      backend,
      nextId: () => 's${_nextId++}-$_bootTag',
      workspaceLabel: workspaceLabel,
      workspaceId: workspaceId,
      configKey: configKey,
      onChanged: notifyListeners,
    );
    _pools[key] = pool;
    return pool;
  }

  /// 关掉工作区 [workspaceId] 的会话池（移除工作区时调用）：进程不再
  /// 残留到空闲回收，后台命令随之终止。
  Future<void> closeWorkspace(String workspaceId) async {
    final pool = _pools.remove(workspaceId);
    if (pool == null) return;
    await pool.closeAll();
    notifyListeners();
  }

  /// 所有池里的所有会话。
  List<PooledWorkspaceSession> allSessions() => [
    for (final pool in _pools.values) ...pool.list(),
  ];

  /// 跨池按 ID 查会话。
  PooledWorkspaceSession? find(String id) {
    for (final pool in _pools.values) {
      final session = pool.find(id);
      if (session != null) return session;
    }
    return null;
  }

  /// 关掉 [test] 命中后端的所有池里的全部会话（如卸载内置终端环境前
  /// 关掉所有 PRoot 会话）。
  Future<void> closeBackends(bool Function(WorkspaceBackend) test) async {
    for (final pool in _pools.values) {
      if (test(pool.backend)) await pool.closeAll();
    }
    notifyListeners();
  }

  /// 把正在等命令结果的会话标记为「在等交互输入」（工具卡片上用户
  /// 手动兜底的入口），返回命中数。传 [sessionRef]（ID 或名称）时只标记
  /// 对应会话，避免并行任务时把无关的长命令也提前打断；不传时标记全部。
  ///
  /// [workspaceId] 非空时只在该工作区的会话里找（同名会话跨工作区不误伤）。
  int markWaitingInputAll({String? sessionRef, String? workspaceId}) {
    var count = 0;
    for (final session in allSessions()) {
      if (workspaceId != null && session.workspaceId != workspaceId) continue;
      if (sessionRef != null &&
          session.id != sessionRef &&
          session.name != sessionRef) {
        continue;
      }
      if (session.markWaitingInput()) count++;
    }
    return count;
  }

  /// 跨池按 ID 关会话；找不到返回 false。
  Future<bool> close(String id) async {
    for (final pool in _pools.values) {
      if (await pool.close(id)) return true;
    }
    return false;
  }
}

@Riverpod(keepAlive: true)
WorkspaceSessionPoolManager workspaceSessionPoolManager(Ref ref) =>
    WorkspaceSessionPoolManager();
