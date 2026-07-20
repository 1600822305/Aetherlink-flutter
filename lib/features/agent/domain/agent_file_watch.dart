/// fileChanged hooks 的文件变更去抖纯逻辑（对标 Claude Code 的
/// FileChanged watcher：awaitWriteFinish 静默窗口）。
///
/// 后端 watch 流的原始事件高频且成簇（一次保存可能触发多条
/// modified），本层按路径合并、静默窗口（[AgentFileChangeDebouncer.quietWindow]）
/// 到期后才吐出一条合并结果；时钟由调用方注入（可测）。执行层
/// （app/di 的 watcher）负责订阅后端流与定时冲刷。
library;

/// 一条去抖后的文件变更（同路径窗口内的事件已合并）。
class AgentWatchedFileChange {
  const AgentWatchedFileChange({required this.path, required this.kind});

  /// 后端的不透明条目标识（SAF 为 content:// URI），仅作 pattern
  /// 文本匹配与透传给 hook，不做路径解析。
  final String path;

  /// 变更类型：created / modified / deleted / moved。
  final String kind;

  @override
  String toString() => 'AgentWatchedFileChange($kind, $path)';
}

/// 合并同一路径静默窗口内的首末变更类型：新建后又删除 → 抵消
/// （返回 null，不触发）；新建后修改 → 仍算新建；其余取末次类型。
String? mergeAgentFileChangeKinds(String first, String last) {
  if (first == 'created' && last == 'deleted') return null;
  if (first == 'created') return 'created';
  return last;
}

/// 按路径去抖：[add] 记录事件并重置该路径的静默计时，[flushDue]
/// 吐出静默窗口已到期的合并结果并移除。
class AgentFileChangeDebouncer {
  AgentFileChangeDebouncer({
    this.quietWindow = const Duration(milliseconds: 500),
  });

  final Duration quietWindow;
  final Map<String, ({String first, String last, DateTime at})> _pending = {};

  bool get isEmpty => _pending.isEmpty;

  void add(String path, String kind, DateTime now) {
    final prev = _pending[path];
    _pending[path] = (first: prev?.first ?? kind, last: kind, at: now);
  }

  List<AgentWatchedFileChange> flushDue(DateTime now) {
    final due = <AgentWatchedFileChange>[];
    final flushed = <String>[];
    _pending.forEach((path, entry) {
      if (now.difference(entry.at) < quietWindow) return;
      flushed.add(path);
      final kind = mergeAgentFileChangeKinds(entry.first, entry.last);
      if (kind != null) {
        due.add(AgentWatchedFileChange(path: path, kind: kind));
      }
    });
    flushed.forEach(_pending.remove);
    return due;
  }
}
