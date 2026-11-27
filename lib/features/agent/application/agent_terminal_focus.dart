// 事件流终端命令 → 工作台终端 tab 的联动跳转请求。
//
// 工具行点「终端」：写入一条请求 → 任务壳翻到工作台页、工作台切到终端
// tab、终端 tab 选中对应会话 chip。终端 tab 首次进入时才创建（离屏保活
// 前不存在），所以请求保留到被消费，由终端 tab 在 initState / 监听里取走。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一次跳转请求。[sessionRef] 为会话 ID 或名称；null 表示「不知道是哪个
/// 会话」（如默认会话的命令仍在运行、结果里还没有 sessionId），由终端 tab
/// 选正在忙的 AI 会话兜底。
class AgentTerminalFocusRequest {
  AgentTerminalFocusRequest({required this.taskId, this.sessionRef})
    : at = DateTime.now();

  final String taskId;
  final String? sessionRef;
  final DateTime at;

  /// 过期的请求不再生效（避免很久之后首次打开终端 tab 被旧请求劫持）。
  bool get fresh => DateTime.now().difference(at) < const Duration(seconds: 5);
}

final agentTerminalFocusProvider =
    NotifierProvider<AgentTerminalFocusNotifier, AgentTerminalFocusRequest?>(
      AgentTerminalFocusNotifier.new,
    );

class AgentTerminalFocusNotifier extends Notifier<AgentTerminalFocusRequest?> {
  @override
  AgentTerminalFocusRequest? build() => null;

  void request(String taskId, {String? sessionRef}) =>
      state = AgentTerminalFocusRequest(taskId: taskId, sessionRef: sessionRef);

  /// 终端 tab 选中会话后调用。
  void consume(AgentTerminalFocusRequest request) {
    if (identical(state, request)) state = null;
  }
}

/// 终端工具调用的目标会话：优先结果里的 `sessionId`（默认会话也有），
/// 其次参数里的 `session` / `session_id`。都没有返回 null。
String? terminalToolSessionRef({String? argsDetail, String? resultDetail}) {
  final result = resultDetail;
  if (result != null && result.isNotEmpty) {
    final m = RegExp(r'"sessionId"\s*:\s*"([^"]+)"').firstMatch(result);
    if (m != null) return m.group(1);
  }
  final raw = argsDetail;
  if (raw == null || raw.isEmpty) return null;
  try {
    final args = jsonDecode(raw);
    if (args is! Map) return null;
    final ref = (args['session'] ?? args['session_id'])?.toString().trim();
    return (ref == null || ref.isEmpty) ? null : ref;
  } on FormatException {
    return null;
  }
}
