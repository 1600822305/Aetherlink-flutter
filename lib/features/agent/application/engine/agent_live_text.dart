// 流式思考 / 正文的实时通道（纯内存，不落库）：引擎每收到一个增量就推
// 一次，正在生成的那一行直接 select 自己的 eventId 拿最新段内容显示，
// 不再等落库 → drift watch → 时间线重折 → 整页重建这条链。落库降频为
// 崩溃恢复用（见 StreamingEventWriter）。
//
// 帧级合并（与聊天页 TurnStreamBinder 同一策略）：两次 vsync 之间的多个
// 增量合并成一次状态发射——空闲时首个增量立即发射（leading edge，无可
// 感知延迟），已有帧在排时挂到下一帧的 frame callback；自适应 60/90/
// 120Hz。后台（帧停产）或无 binding（纯 Dart 测试）时直接发射。

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 引擎侧写入口（抽象出来让引擎不依赖 riverpod，测试可注 fake）。
abstract class AgentLiveTextSink {
  /// 事件 [eventId] 当前段的最新全文。
  void update(String eventId, String text);

  /// 段定稿后释放。延迟一小段时间再真正移除：定稿落库到 drift watch
  /// 回推之间，UI 拿到的事件可能还是旧的流式快照，立刻移除会闪回旧
  /// 文本（看起来像丢字）。
  void clear(String eventId);
}

/// 定稿后保留实时文本的时长（足够盖住落库 → watch 回推的延迟）。
const Duration kLiveTextClearDelay = Duration(seconds: 2);

/// 两次 vsync 之间合并发射的调度器（latest-wins）。
class FrameCoalescer {
  FrameCoalescer(this._emit);

  final void Function() _emit;
  int? _pendingFrame;

  void schedule() {
    SchedulerBinding? scheduler;
    try {
      scheduler = SchedulerBinding.instance;
    } catch (_) {
      scheduler = null;
    }
    if (scheduler == null || !scheduler.framesEnabled) {
      _cancel(scheduler);
      _emit();
      return;
    }
    if (_pendingFrame != null) return;
    if (scheduler.schedulerPhase == SchedulerPhase.idle &&
        !scheduler.hasScheduledFrame) {
      _emit();
      return;
    }
    _pendingFrame = scheduler.scheduleFrameCallback((_) {
      _pendingFrame = null;
      _emit();
    });
  }

  void _cancel(SchedulerBinding? scheduler) {
    final id = _pendingFrame;
    if (id == null) return;
    _pendingFrame = null;
    scheduler?.cancelFrameCallbackWithId(id);
  }

  void dispose() {
    try {
      _cancel(SchedulerBinding.instance);
    } catch (_) {
      _pendingFrame = null;
    }
  }
}

class AgentLiveTextNotifier extends Notifier<Map<String, String>>
    implements AgentLiveTextSink {
  final Map<String, String> _pending = {};
  final Map<String, Timer> _clearTimers = {};
  late final FrameCoalescer _coalescer = FrameCoalescer(_flush);

  @override
  Map<String, String> build() {
    ref.onDispose(() {
      _coalescer.dispose();
      for (final t in _clearTimers.values) {
        t.cancel();
      }
      _clearTimers.clear();
    });
    return const {};
  }

  @override
  void update(String eventId, String text) {
    _clearTimers.remove(eventId)?.cancel();
    _pending[eventId] = text;
    _coalescer.schedule();
  }

  @override
  void clear(String eventId) {
    _clearTimers.remove(eventId)?.cancel();
    _clearTimers[eventId] = Timer(kLiveTextClearDelay, () {
      _clearTimers.remove(eventId);
      _pending.remove(eventId);
      if (!state.containsKey(eventId)) return;
      state = Map.of(state)..remove(eventId);
    });
  }

  void _flush() {
    if (_pending.isEmpty) return;
    state = {...state, ..._pending};
    _pending.clear();
  }
}

/// eventId → 当前段实时全文。正在生成的行 `select((m) => m[id])` 只重建自己。
final agentLiveTextProvider =
    NotifierProvider<AgentLiveTextNotifier, Map<String, String>>(
      AgentLiveTextNotifier.new,
    );

/// 流式事件的展示文本：实时通道比落库快照更新（同段内只增不减）时用实时
/// 值，否则用事件自身文本（定稿 / 实时已释放 / 无实时通道）。
String liveOrStored(String? live, String stored, {required bool streaming}) {
  if (!streaming || live == null) return stored;
  return live.length >= stored.length ? live : stored;
}
