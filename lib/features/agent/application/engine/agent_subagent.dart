/// 子代理（subagent，初稿 §5.5 P2）：主任务经 [kToolSpawnSubagent] 派生
/// 独立上下文的子循环干专项活，只把最终结论带回主上下文（对标
/// Cursor/Claude Code：上下文隔离 + 并行）。
library;

import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

const String kToolSpawnSubagent = 'spawn_subagent';

/// 子代理类型（对标 Cursor 内置子代理）。
enum AgentSubagentType {
  /// 只读探索：大范围搜索/调研/读代码，工具集为只读子集，零审批。
  explore,

  /// 终端执行：跑一串命令并总结，把啰嗦输出隔离在子上下文里。
  bash,
}

/// 模型侧工具定义：同一轮发多个 spawn_subagent 调用即并行执行。
const kSpawnSubagentToolDefinition = McpToolDefinition(
  name: kToolSpawnSubagent,
  description: '派生一个子代理在独立上下文里完成专项子任务，只把最终结论带回。'
      '适合会产生大量中间输出的活（大范围搜索/调研、跑一串命令看结果），'
      '避免噪音挤爆主上下文。type=explore 为只读探索（搜索/读文件/调研），'
      'type=bash 为终端执行（Ask/Plan 模式下不可用）；也可填系统提示里列出的'
      '自定义子代理档案名。子代理没有本对话的记忆，prompt 必须自带全部必要'
      '上下文。同一轮发多个调用即并行执行。background=true 时不阻塞当前循环：'
      '立即返回「已启动」，子代理完成后结论回填本工具结果并以消息注入对话。',
  inputSchema: {
    'type': 'object',
    'properties': {
      'type': {
        'type': 'string',
        'description': '子代理类型：explore 只读探索 / bash 终端执行 / '
            '自定义档案名（系统提示的「自定义子代理档案」清单里列出的 name）',
      },
      'prompt': {
        'type': 'string',
        'description': '子任务的完整指令（自带全部必要上下文，'
            '并说明期望返回什么样的结论）',
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
