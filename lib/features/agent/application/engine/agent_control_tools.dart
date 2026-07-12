import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// 引擎控制工具的模型侧定义（初稿 §5.4）：这三个工具由引擎内部处理，
/// 不进 [AgentToolExecutor]，但需要作为 function 定义暴露给模型。
const List<McpToolDefinition> kAgentControlToolDefinitions = [
  McpToolDefinition(
    name: kToolUpdatePlan,
    description: '维护任务计划（全量覆盖式提交）。复杂任务开始时先提交完整计划，'
        '之后每完成/开始一项就重新提交全量条目以更新状态。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'items': {
          'type': 'array',
          'description': '全量计划条目列表（覆盖之前的计划）。',
          'items': {
            'type': 'object',
            'properties': {
              'content': {'type': 'string', 'description': '条目内容'},
              'status': {
                'type': 'string',
                'enum': ['pending', 'in_progress', 'completed'],
              },
            },
            'required': ['content', 'status'],
          },
        },
      },
      'required': ['items'],
    },
  ),
  McpToolDefinition(
    name: kToolAskUser,
    description: '向用户提问并暂停任务等待回复。仅在缺少关键信息、'
        '或决策不可逆且无法自行判断时使用。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'question': {'type': 'string', 'description': '要问用户的问题'},
      },
      'required': ['question'],
    },
  ),
  McpToolDefinition(
    name: kToolFinishTask,
    description: '声明任务完成并结束循环。附一句简要总结说明完成了什么。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'summary': {'type': 'string', 'description': '完成情况的简要总结'},
      },
      'required': ['summary'],
    },
  ),
];
