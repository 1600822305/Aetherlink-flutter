import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/browser_exception.dart';
import 'browser_session.dart';

/// 会话工厂（可注入 mock，测试无需 WebView）。
typedef SessionFactory = BrowserSession Function();

/// 会话所有权（升级设计 §2.4 M4d，借鉴 ego-lite Task Space 模型）。
/// 宽松共驾语义：所有权只标记“谁在主导”，不限制另一方操作——
/// 非 agent 所有时 agent 工具仍可调用，只在结果中提示用户可能
/// 同时在操作；用户则随时可在共驾页查看/操作任意会话。
enum SessionOwnership {
  /// agent 主导。
  agent,

  /// agent 已交给用户（登录/验证码等），等用户完成；会话不参与
  /// 空闲释放/LRU 回收。
  delegatedToUser,

  /// 用户主导（在共驾页主动标记）；同上，不参与回收。
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
/// 会话不参与 LRU 回收与空闲释放（用户可能正在看/操作），但不限制
/// agent 工具调用（宽松共驾）。
class BrowserSessionManager extends ChangeNotifier {
  BrowserSessionManager({
    required SessionFactory factory,
    this.idleTimeout = const Duration(minutes: 5),
    this.maxConsecutiveFailures = 2,
    this.maxSessions = 3,
    this.heartbeatAfter = const Duration(seconds: 60),
  }) : _factory = factory;

  final SessionFactory _factory;

  /// 空闲超过该时长自动释放 WebView（下次调用重建）。
  final Duration idleTimeout;

  /// 同会话连续卡死/超时次数达到该值后 dispose 重建（设计稿 §19.2：
  /// 防 WebView 本身进入坏状态）。
  final int maxConsecutiveFailures;

  /// 同时存活的 WebView 上限（移动端内存敏感）。
  final int maxSessions;

  /// 闲置超过该时长的会话在下次使用前先心跳探活，挂死则重建
  /// 并透明恢复，避免把死会话交给调用方以超时失败。
  final Duration heartbeatAfter;

  /// 缺省会话 id（工具不带 session 参数时使用）。
  static const String defaultSessionId = 'default';

  /// 插入顺序即 LRU 顺序：每次使用移到末尾，回收从头部找。
  final LinkedHashMap<String, _SessionEntry> _entries =
      LinkedHashMap<String, _SessionEntry>();
  bool _closed = false;

  /// 已回收会话的最后 URL（条目被移除后仍保留，供透明恢复），
  /// 容量封顶防无限增长。
  final LinkedHashMap<String, String> _recentUrls =
      LinkedHashMap<String, String>();
  static const int _recentUrlsCap = 16;

  /// 互斥串行执行 [action]：同一会话的并发调用按提交顺序排队
  /// （子代理并行时也不会互相打断导航）；不同会话互不阻塞。
  Future<T> run<T>(
    Future<T> Function(BrowserSession session) action, {
    String? sessionId,
  }) {
    if (_closed) {
      throw const BrowserException(BrowserErrorKind.sessionGone, '浏览器管理器已关闭');
    }
    final id = _normalize(sessionId);
    final entry = _entryFor(id);
    // 即将新建 WebView 时先回收触底的 LRU 会话，并等回收完成再建，
    // 保证存活 WebView 数不瞬时超过 maxSessions。
    final evicted = entry.session == null && entry.pending == 0
        ? _evictIfNeeded(entry)
        : null;
    entry.pending++;
    final result = entry.queue.then((_) async {
      if (evicted != null) await evicted;
      return _runLocked(entry, action);
    });
    entry.queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<T> _runLocked<T>(
    _SessionEntry entry,
    Future<T> Function(BrowserSession session) action,
  ) async {
    entry.idleTimer?.cancel();
    // 崩溃/挂死的会话在交给动作前主动重建（而非等调用以诡异
    // 错误失败）：渲染进程被系统杀掉 / 心跳探针无响应都算。
    final existing = entry.session;
    if (existing != null) {
      var dead = existing.crashed;
      if (!dead &&
          entry.lastUsed != null &&
          DateTime.now().difference(entry.lastUsed!) >= heartbeatAfter) {
        dead = !await existing.isResponsive();
      }
      if (dead) await _disposeEntry(entry);
    }
    final created = entry.session == null;
    final session = entry.session ??= _factory();
    if (created) {
      notifyListeners();
      // 透明恢复：重建的会话预约重开上次页面（惰性，显式 open
      // 会跳过），cookie 全局共享登录态不丢；@N 需重新快照。
      final restore = entry.lastUrl ?? _recentUrls[entry.id];
      if (restore != null) session.scheduleRestore(restore);
    }
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
      entry.pending--;
      entry.lastUsed = DateTime.now();
      final liveSession = entry.session;
      if (liveSession != null) {
        entry.lastUrl = liveSession.lastUrl ?? entry.lastUrl;
      }
      if (!_closed &&
          entry.session != null &&
          entry.ownership == SessionOwnership.agent) {
        entry.idleTimer = Timer(idleTimeout, () {
          // 共驾页可见挂载的会话不回收（用户可能正在看）。
          if (entry.session?.visibleAttached == true) return;
          _disposeEntry(entry);
        });
      }
    }
  }

  /// 取/建会话条目（不触发回收；回收在 [run] 即将新建 WebView 时做）。
  _SessionEntry _entryFor(String id) {
    final existing = _entries.remove(id);
    if (existing != null) {
      _entries[id] = existing; // 移到末尾（最近使用）。
      return existing;
    }
    final entry = _SessionEntry(id);
    _entries[id] = entry;
    notifyListeners();
    return entry;
  }

  /// 只查不建：所有权/交接类操作不应为不存在的会话创建幽灵条目。
  _SessionEntry? _existingEntry(String? sessionId) =>
      _entries[_normalize(sessionId)];

  /// LRU 触底回收（跳过 [about] 自身、非 agent 所有及共驾可见挂载的
  /// 会话）；返回回收完成的 Future（无需回收时为 null）。
  Future<void>? _evictIfNeeded(_SessionEntry about) {
    final live = _entries.values.where((e) => e.session != null).length;
    if (live < maxSessions) return null;
    for (final entry in _entries.values) {
      if (entry == about) continue;
      if (entry.session != null &&
          entry.ownership == SessionOwnership.agent &&
          entry.session?.visibleAttached != true) {
        // 回收挂进该会话自己的队列，不打断正在执行的操作。
        final disposed = entry.queue.then((_) => _disposeEntry(entry));
        entry.queue = disposed.then<void>((_) {}, onError: (_) {});
        return disposed;
      }
    }
    throw BrowserException(
      BrowserErrorKind.sessionLimit,
      '浏览器会话数已达上限（$maxSessions）且均在用户控制/查看中，'
      '无法新建；可等用户交回或复用现有会话',
    );
  }

  /// agent 把会话交给用户（登录/验证码/滑块等）：标记主导方并提醒
  /// 用户去共驾页操作；不限制 agent 后续调用（宽松共驾）。
  void handOff(String? sessionId, {String? note, String? url}) {
    final entry = _existingEntry(sessionId);
    if (entry == null) return; // 从未用过的会话无可交接，不建幽灵条目。
    entry.ownership = SessionOwnership.delegatedToUser;
    entry.handOffNote = note;
    entry.handOffUrl = url;
    entry.idleTimer?.cancel();
    entry.idleTimer = null;
    notifyListeners();
  }

  /// 收回会话控制权（用户确认后由工具层调用；用户也可在 UI 主动交回）。
  void takeOver(String? sessionId) {
    final entry = _existingEntry(sessionId);
    if (entry == null) return;
    entry.ownership = SessionOwnership.agent;
    entry.handOffNote = null;
    entry.handOffUrl = null;
    notifyListeners();
  }

  /// 用户从 UI 主动接管会话（对应 [SessionOwnership.user]）。
  void userClaim(String? sessionId) {
    final entry = _existingEntry(sessionId);
    if (entry == null) return;
    entry.ownership = SessionOwnership.user;
    entry.idleTimer?.cancel();
    entry.idleTimer = null;
    notifyListeners();
  }

  /// 取已存在的会话实例（不创建；共驾页可见挂载用）。
  BrowserSession? peekSession(String? sessionId) =>
      _entries[_normalize(sessionId)]?.session;

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
    // 回收前保存最后 URL，下次使用时透明恢复（条目被移除也能从
    // [_recentUrls] 找回）。
    final lastUrl = session?.lastUrl ?? entry.lastUrl;
    if (lastUrl != null) {
      entry.lastUrl = lastUrl;
      _recentUrls.remove(entry.id);
      _recentUrls[entry.id] = lastUrl;
      while (_recentUrls.length > _recentUrlsCap) {
        _recentUrls.remove(_recentUrls.keys.first);
      }
    }
    // 无特殊状态且无排队调用的条目直接移除，避免 _entries 只增不减
    //（共驾页会话列表无限累积）。
    if (!_closed &&
        entry.pending == 0 &&
        entry.ownership == SessionOwnership.agent &&
        _entries[entry.id] == entry) {
      _entries.remove(entry.id);
    }
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

  /// 已排队/执行中的调用数：>0 时不从 [_entries] 移除，防止后续
  /// 排队调用在孤儿条目上重建会话。
  int pending = 0;
  int consecutiveFailures = 0;
  SessionOwnership ownership = SessionOwnership.agent;
  String? handOffNote;
  String? handOffUrl;

  /// 最后一次已知页面 URL（回收后透明恢复用）。
  String? lastUrl;

  /// 最后一次调用完成时间（心跳探活阈值用）。
  DateTime? lastUsed;
}
