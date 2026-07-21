/// 子代理（subagent，初稿 §5.5 P2）：主任务经 [kToolSpawnSubagent] 派生
/// 独立上下文的子循环干专项活，只把最终结论带回主上下文（对标
/// Cursor/Claude Code：上下文隔离 + 并行）。
library;

import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

const String kToolSpawnSubagent = 'spawn_subagent';

/// 子代理类型（对标 Cursor 内置子代理）。
enum AgentSubagentType {
  /// 只读探索：大范围搜索/调研/读代码，工具集为只读子集，零审批。
  explore,

  /// 终端执行：跑一串命令并总结，把啰嗦输出隔离在子上下文里。
  bash,

  /// 分身（对标 Claude Code fork）：继承父任务对话上下文的摘录，
  /// prompt 只需给指令不用重述背景；工具/模式与父任务一致。
  fork,
}

/// 模型侧工具定义：同一轮发多个 spawn_subagent 调用即并行执行。
const kSpawnSubagentToolDefinition = McpToolDefinition(
  name: kToolSpawnSubagent,
  description: '派生一个子代理在独立上下文里完成专项子任务，只把最终结论带回。'
      '首次使用前先用 read_skill 读取「子代理派发」技能获取完整用法。'
      '子代理没有本对话的记忆，prompt 必须自带全部必要上下文。',
  inputSchema: {
    'type': 'object',
    'properties': {
      'type': {
        'type': 'string',
        'description': '子代理类型：explore 只读探索 / bash 终端执行 / '
            'fork 分身（继承本对话上下文摘录，prompt 只写指令）/ '
            '自定义档案名（系统提示的「自定义子代理档案」清单里列出的 name）',
      },
      'prompt': {
        'type': 'string',
        'description': '子任务的完整指令。fork 之外的类型没有本对话记忆，'
            '必须自带全部必要上下文，并说明期望返回什么样的结论',
      },
      'description': {
        'type': 'string',
        'description': '子任务的一句话标题（3~8 个词，展示用）',
      },
      'background': {
        'type': 'boolean',
        'description': '后台运行（默认 false）：不阻塞当前循环，'
            '完成后结论以消息注入对话',
      },
    },
    'required': ['type', 'prompt'],
  },
);

/// 子代理启动器抽象：真实实现经 runner 组装子引擎（独立事件流/预算），
/// 引擎只见此接口。[toolEventId] 用于派生子任务 id（UI 由此定位子事件流）。
abstract class AgentSubagentLauncher {
  Future<AgentToolResult> launch({
    required AgentTask parent,
    required AgentToolCallRequest call,
    required String toolEventId,
    required AgentCancellationToken cancel,
  });
}

/// 子任务 id 派生规则（launcher 与 UI 共用）。
String subagentTaskIdFor(String toolEventId) => 'sub-$toolEventId';

/// fork 分身的父上下文摘录（纯函数）：把父任务事件流序列化为可读
/// 转写文本注入子代理首条消息——用户/助手正文全文、工具调用一行
/// 摘要、压缩摘要正文；超出 [maxChars] 时从头部截断保留最近内容
///（越新越相关）。
String buildSubagentForkContext(
  List<AgentEvent> events, {
  int maxChars = 24000,
}) {
  final lines = <String>[];
  for (final e in events) {
    switch (e) {
      case UserMessageEvent(:final text):
        if (text.trim().isNotEmpty) lines.add('[用户] $text');
      case AssistantTextEvent(:final text, streaming: false):
        if (text.trim().isNotEmpty) lines.add('[助手] $text');
      case ToolCallEvent(:final toolName, :final argSummary, :final resultSummary):
        lines.add(
          '[工具 $toolName] $argSummary'
          '${resultSummary.isNotEmpty ? ' → $resultSummary' : ''}',
        );
      case CompactionEvent(:final summary, revoked: false):
        if (summary.trim().isNotEmpty) lines.add('[较早内容摘要] $summary');
      default:
        break;
    }
  }
  var text = lines.join('\n\n');
  if (text.length > maxChars) {
    text = '（更早内容已截断）\n…${text.substring(text.length - maxChars)}';
  }
  return text;
}
