import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks `run_command` tool calls that are currently executing on a workspace
/// backend so the chat UI can offer a 中断 (interrupt) affordance.
///
/// Flow (sibling to [ToolConfirmationNotifier]):
///  1. After the user approves a `run_command` call, the chat controller calls
///     [start] with the tool block's id and threads the returned future into
///     `WorkspaceBackend.exec` as its `cancelSignal`.
///  2. The block id is added to [state]; the run_command block view watches it
///     and shows a 中断 button while the command runs.
///  3. The user taps 中断 → [cancel] completes the signal → the backend kills
///     the session and `exec` returns with `canceled = true`.
///  4. The controller calls [finish] in a `finally` once the command settles.
class RunningCommandsNotifier extends Notifier<Set<String>> {
  /// Cancel signals keyed by tool block id. Completing one aborts that command.
  final _cancelers = <String, Completer<void>>{};

  @override
  Set<String> build() => const {};

  /// Begins tracking [blockId] as a running, cancelable command. Returns the
  /// cancel signal to pass to `exec`; it completes when [cancel] is called.
  Future<void> start(String blockId) {
    final completer = _cancelers.putIfAbsent(blockId, Completer<void>.new);
    if (!state.contains(blockId)) state = {...state, blockId};
    return completer.future;
  }

  /// Stops tracking [blockId] (the command finished, errored, or was canceled).
  void finish(String blockId) {
    _cancelers.remove(blockId);
    if (!state.contains(blockId)) return;
    state = {...state}..remove(blockId);
  }

  /// Whether [blockId]'s command is still running.
  bool isRunning(String blockId) => state.contains(blockId);

  /// User requested interruption of [blockId]'s running command.
  void cancel(String blockId) {
    final completer = _cancelers[blockId];
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  /// Cancels every running command (e.g. when the whole turn is aborted).
  void cancelAll() {
    for (final completer in _cancelers.values) {
      if (!completer.isCompleted) completer.complete();
    }
  }
}

final runningCommandsProvider =
    NotifierProvider<RunningCommandsNotifier, Set<String>>(
      RunningCommandsNotifier.new,
    );

/// 单个工具块保留的实时输出尾部上限（字符），防长输出撑爆 UI/内存。
const int kLiveOutputTailLimit = 8 * 1024;

/// 运行中命令的实时输出（按工具块 id 键控）。
///
/// 命令执行期间后端把 stdout/stderr 分块回调进来（[append]），命令卡片
/// watch 自己块的条目实时渲染；命令结束后 [clear] 释放（最终输出走工具
/// 结果 JSON，与实时缓冲无关）。
class CommandLiveOutputNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  /// 追加 [blockId] 的一块实时输出，只保留尾部 [kLiveOutputTailLimit] 字符。
  void append(String blockId, String chunk) {
    if (chunk.isEmpty) return;
    var text = (state[blockId] ?? '') + chunk;
    if (text.length > kLiveOutputTailLimit) {
      text = text.substring(text.length - kLiveOutputTailLimit);
    }
    state = {...state, blockId: text};
  }

  /// 命令结束（完成 / 出错 / 被中断）后释放 [blockId] 的缓冲。
  void clear(String blockId) {
    if (!state.containsKey(blockId)) return;
    state = {...state}..remove(blockId);
  }
}

final commandLiveOutputProvider =
    NotifierProvider<CommandLiveOutputNotifier, Map<String, String>>(
      CommandLiveOutputNotifier.new,
    );
