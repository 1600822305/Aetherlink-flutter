/// 辩论引擎与聊天域之间的端口。
///
/// 引擎（`debate_engine.dart`）是纯 Dart 状态机，不直接依赖 chat 的
/// application 层；由 `app/di/debate_access.dart` 提供把发言写成助手消息的
/// 实现，单测里用 fake 替换。
library;

import 'package:aetherlink_flutter/features/debate/domain/debate_models.dart';

/// 一次角色发言请求。
class DebateSpeakRequest {
  const DebateSpeakRequest({
    required this.role,
    required this.round,
    required this.system,
    required this.prompt,
    required this.header,
    this.metadata,
    this.toolsEnabled = false,
  });

  final DebateRole role;

  /// 第几轮；总结阶段为 0。
  final int round;

  /// 角色人设（作为 system prompt 发送）。
  final String system;

  /// 本次发言的完整上下文（作为 user 消息发送）。
  final String prompt;

  /// 渲染在消息顶部的标题 Markdown（如 `**第1轮 - 正方辩手** (正方)`）。
  final String header;

  /// 写入消息 `metadata['debate']` 的结构化标记。
  final Map<String, dynamic>? metadata;

  /// 允许本次发言调用工具（联网搜索 / MCP），供事实核查类角色使用。
  final bool toolsEnabled;
}

class DebateSpeakResult {
  const DebateSpeakResult({this.text, this.failed = false, this.messageId});

  /// 未配置/无法解析模型时的结果——引擎会明确提示并跳过，
  /// 不产出假的模拟回复（web 的降级模拟响应不迁移）。
  static const DebateSpeakResult noModel = DebateSpeakResult(failed: true);

  /// 流式完成后的最终文本；null/空 表示失败或被中断。
  final String? text;
  final bool failed;

  /// 落地的助手消息 id（仅 [DebateChatPort.speak] 产出），供 TTS 朗读定位。
  final String? messageId;

  bool get succeeded => !failed && (text?.trim().isNotEmpty ?? false);
}

abstract class DebateChatPort {
  /// 以 [DebateSpeakRequest.role] 指定的模型发起一条流式助手消息，
  /// 返回最终文本。
  Future<DebateSpeakResult> speak(DebateSpeakRequest request);

  /// 静默一次性生成（不落聊天消息），用于裁决 JSON 等结构化产出。
  Future<DebateSpeakResult> generate(DebateSpeakRequest request);

  /// 写一条无模型的系统通告消息（开场、结束、裁决卡片、错误提示）。
  Future<void> announce(String markdown, {Map<String, dynamic>? metadata});

  /// 注册/清除用户插话监听：辩论进行中用户从输入框发送的消息会被拦截成
  /// 「场外发言」——落一条普通用户消息后回调 [listener]，不触发常规模型回复。
  void setInterjectionListener(void Function(String text)? listener);

  /// 朗读一条发言（复用 voice 的 TTS，不阻塞引擎流程）。
  void readAloud(String text, {required String messageId});

  /// 中断当前话题正在进行的流式请求（用户停止辩论时）。
  void cancelActiveStream();
}
