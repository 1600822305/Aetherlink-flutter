import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/browser_exception.dart';
import 'browser_session.dart';

/// 会话工厂（可注入 mock，测试无需 WebView）。
typedef SessionFactory = BrowserSession Function();

/// 会话所有权（升级设计 §2.4 M4d，借鉴 ego-lite Task Space 模型）。
enum SessionOwnership {
  /// agent 拥有：工具可正常操作。
  agent,

  /// agent 已交给用户（登录/验证码等），等用户交回；工具操作硬停止。
  delegatedToUser,

  /// 用户主动接管；工具操作硬停止。
  user,
}

/// 单个会话的状态快照（UI/诊断用）。
class BrowserSessionInfo {
  const BrowserSessionInfo({
    required this.id,
    required this.ownership,
    required this.alive,
    this.handOffNote,
    this.handOffUrl,
  });

  final String id;
  final SessionOwnership ownership;
  final bool alive;

  /// handOff 时 agent 留给用户的说明/当时页面 URL。
  final String? handOffNote;
  final String? handOffUrl;
}

/// 会话管理（升级设计 §2.4 M4d）：从"单实例忽略 sessionId"升级为
/// 真多会话池——按 id 建/复用独立 WebView（上限 [maxSessions]，LRU
/// 回收 agent 拥有的空闲会话），cookie 全局共享（WebView 平台特性）。
/// 每个会话独立互斥队列串行 + 空闲超时释放；所有权为 agent 之外的
/// 会话对工具调用硬停止（返回明确错误，agent 不得重试绕过），且不参与
/// LRU 回收与空闲释放。
class BrowserSessionManager extends ChangeNotifier {
  BrowserSessionManager({
    required SessionFactory factory,
    this.idleTimeout = const Duration(minutes: 5),
    this.maxConsecutiveFailures = 2,
    this.maxSessions = 3,
  }) : _factory = factory;

  final SessionFactory _factory;

  /// 空闲超过该时长自动释放 WebView（下次调用重建）。
  final Duration idleTimeout;

  /// 同会话连续卡死/超时次数达到该值后 dispose 重建（设计稿 §19.2：
  /// 防 WebView 本身进入坏状态）。
  final int maxConsecutiveFailures;

  /// 同时存活的 WebView 上限（移动端内存敏感）。
  final int maxSessions;

  /// 缺省会话 id（工具不带 session 参数时使用）。
  static const String defaultSessionId = 'default';

  /// 插入顺序即 LRU 顺序：每次使用移到末尾，回收从头部找。
  final LinkedHashMap<String, _SessionEntry> _entries =
      LinkedHashMap<String, _SessionEntry>();
  bool _closed = false;

  /// 互斥串行执行 [action]：同一会话的并发调用按提交顺序排队
  /// （子代理并行时也不会互相打断导航）；不同会话互不阻塞。
  Future<T> run<T>(
    Future<T> Function(BrowserSession session) action, {
    String? sessionId,
  }) {
    if (_closed) {
      throw const BrowserException(
        BrowserErrorKind.sessionGone,
        '浏览器管理器已关闭',
      );
    }
    final id = _normalize(sessionId);
    final entry = _entryFor(id);
    if (entry.ownership != SessionOwnership.agent) {
      throw BrowserException(
        BrowserErrorKind.userControlled,
        '会话 "$id" 当前由用户控制中（${entry.ownership.name}）：不要重试，'
        '等用户操作完成后用 browser_take_over 收回，或改用其他会话',
      );
    }
    final result = entry.queue.then((_) => _runLocked(entry, action));
    entry.queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<T> _runLocked<T>(
    _SessionEntry entry,
    Future<T> Function(BrowserSession session) action,
  ) async {
    entry.idleTimer?.cancel();
    final created = entry.session == null;
    final session = entry.session ??= _factory();
    if (created) notifyListeners();
    try {
      final value = await action(session);
      entry.consecutiveFailures = 0;
      return value;
    } on BrowserException catch (e) {
      if (e.kind == BrowserErrorKind.navigationTimeout ||
          e.kind == BrowserErrorKind.scriptTimeout) {
        entry.consecutiveFailures++;
        if (entry.consecutiveFailures >= maxConsecutiveFailures) {
          entry.consecutiveFailures = 0;
          await _disposeEntry(entry);
        }
      }
      rethrow;
    } finally {
      if (!_closed &&
          entry.session != null &&
          entry.ownership == SessionOwnership.agent) {
        entry.idleTimer = Timer(idleTimeout, () => _disposeEntry(entry));
      }
    }
  }

  /// 取/建会话条目，并做 LRU 触底回收（只回收 agent 拥有的其他会话）。
  _SessionEntry _entryFor(String id) {
    final existing = _entries.remove(id);
    if (existing != null) {
      _entries[id] = existing; // 移到末尾（最近使用）。
      return existing;
    }
    _evictIfNeeded();
    final entry = _SessionEntry(id);
    _entries[id] = entry;
    notifyListeners();
    return entry;
  }

  void _evictIfNeeded() {
    final live = _entries.values.where((e) => e.session != null).length;
    if (live < maxSessions) return;
    for (final entry in _entries.values) {
      if (entry.session != null && entry.ownership == SessionOwnership.agent) {
        // 回收挂进该会话自己的队列，不打断正在执行的操作。
        entry.queue = entry.queue
            .then((_) => _disposeEntry(entry))
            .then<void>((_) {}, onError: (_) {});
        return;
      }
    }
    throw BrowserException(
      BrowserErrorKind.sessionLimit,
      '浏览器会话数已达上限（$maxSessions）且均在用户控制中，'
      '无法新建；可等用户交回或复用现有会话',
    );
  }

  /// agent 把会话交给用户（登录/验证码/滑块等）。之后该会话的工具
  /// 操作硬停止，直到 [takeOver]。
  void handOff(String? sessionId, {String? note, String? url}) {
    final entry = _entryFor(_normalize(sessionId));
    entry.ownership = SessionOwnership.delegatedToUser;
    entry.handOffNote = note;
    entry.handOffUrl = url;
    entry.idleTimer?.cancel();
    entry.idleTimer = null;
    notifyListeners();
  }

  /// 收回会话控制权（用户确认后由工具层调用；用户也可在 UI 主动交回）。
  void takeOver(String? sessionId) {
    final entry = _entryFor(_normalize(sessionId));
    entry.ownership = SessionOwnership.agent;
    entry.handOffNote = null;
    entry.handOffUrl = null;
    notifyListeners();
  }

  /// 用户从 UI 主动接管会话（对应 [SessionOwnership.user]）。
  void userClaim(String? sessionId) {
    final entry = _entryFor(_normalize(sessionId));
    entry.ownership = SessionOwnership.user;
    entry.idleTimer?.cancel();
    entry.idleTimer = null;
    notifyListeners();
  }

  /// 会话所有权（不存在的会话视为 agent 拥有——首次使用即创建）。
  SessionOwnership ownershipOf(String? sessionId) =>
      _entries[_normalize(sessionId)]?.ownership ?? SessionOwnership.agent;

  /// 交接备注（handOff 时 agent 留给用户的说明）。
  String? handOffNoteOf(String? sessionId) =>
      _entries[_normalize(sessionId)]?.handOffNote;

  /// 当前所有会话的状态快照（UI/诊断用）。
  List<BrowserSessionInfo> get sessionInfos => _entries.values
      .map(
        (e) => BrowserSessionInfo(
          id: e.id,
          ownership: e.ownership,
          alive: e.session != null && !e.session!.disposed,
          handOffNote: e.handOffNote,
          handOffUrl: e.handOffUrl,
        ),
      )
      .toList();

  static String _normalize(String? sessionId) {
    final id = sessionId?.trim() ?? '';
    return id.isEmpty ? defaultSessionId : id;
  }

  Future<void> _disposeEntry(_SessionEntry entry) async {
    entry.idleTimer?.cancel();
    entry.idleTimer = null;
    final session = entry.session;
    entry.session = null;
    if (session != null) {
      await session.close();
      notifyListeners();
    }
  }

  /// 是否存在存活的 WebView（测试/诊断用）。
  bool get hasLiveSession =>
      _entries.values.any((e) => e.session != null && !e.session!.disposed);

  /// App 退出/引擎停止时调用：释放所有 WebView 并拒绝后续调用。
  Future<void> closeAll() async {
    _closed = true;
    for (final entry in _entries.values.toList()) {
      await _disposeEntry(entry);
    }
    _entries.clear();
  }
}

class _SessionEntry {
  _SessionEntry(this.id);

  final String id;
  BrowserSession? session;
  Future<void> queue = Future<void>.value();
  Timer? idleTimer;
  int consecutiveFailures = 0;
  SessionOwnership ownership = SessionOwnership.agent;
  String? handOffNote;
  String? handOffUrl;
}
