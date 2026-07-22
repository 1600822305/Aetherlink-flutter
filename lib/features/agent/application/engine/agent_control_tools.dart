import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// 引擎控制工具的模型侧定义（初稿 §5.4）：这三个工具由引擎内部处理，
/// 不进 [AgentToolExecutor]，但需要作为 function 定义暴露给模型。
const List<McpToolDefinition> kAgentControlToolDefinitions = [
  McpToolDefinition(
    name: kToolUpdatePlan,
    description: '维护任务计划（全量覆盖式提交）。复杂任务开始时先提交完整计划，'
        '之后每完成/开始一项就重新提交全量条目以更新状态；同一时间恰好一项 '
        'in_progress。全部条目 completed 时提交即收尾（计划自动清空）；'
        '不要提交空列表。',
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
    description: '向用户提出一个问题以获取继续任务所需的信息，任务会暂停等待回复。'
        '仅在缺少关键信息、或决策不可逆且无法自行判断时使用。'
        '必须同时给出 2-4 个建议答案，每个都是完整、可直接采用的回答'
        '（不要占位符）；用户也可以输入自定义回答。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'question': {
          'type': 'string',
          'description': '清晰、具体的问题，直指缺失的信息',
        },
        'follow_up': {
          'type': 'array',
          'minItems': 2,
          'maxItems': 4,
          'items': {'type': 'string'},
          'description': '2-4 个建议答案；每个必须是完整、可直接采用的回答，不含占位符',
        },
      },
      'required': ['question', 'follow_up'],
    },
  ),
  McpToolDefinition(
    name: kToolFinishTask,
    description: '声明任务完成并结束循环。调用前必须已把面向用户的最终答复/报告'
        '作为正文输出（分析、调研、解答类任务的正文就是交付物，没有正文的收尾'
        '会被拒绝）；summary 只是给任务列表看的一句话标题，不能替代正文。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'summary': {
          'type': 'string',
          'description': '一句话标题式总结（展示在任务列表，不替代正文）',
        },
      },
      'required': ['summary'],
    },
  ),
];

/// enter_plan_mode（对标 CC EnterPlanModeTool）：仅在 Code/Auto 模式且
/// 顶层任务（非子代理）时注入；引擎内部处理，调用后任务切入 Plan 模式。
const McpToolDefinition kEnterPlanModeToolDefinition = McpToolDefinition(
  name: kToolEnterPlanMode,
  description: '进入计划模式：任务复杂、有多种可行实现方案、涉及既有行为变更或多文件改动、'
      '或需求不够明确时使用——先只读探索代码并设计方案，经用户批准后再动手实现。'
      '进入后写类工具与终端将不可用，只能只读探索 + 用 update_plan 维护方案，'
      '方案就绪后调用 exit_plan_mode 请求用户批准。'
      '简单明确的小改动（单处修复、用户已给出明确指令）不要使用。',
  inputSchema: {'type': 'object', 'properties': <String, Object?>{}},
);

/// exit_plan_mode（对标 CC ExitPlanModeTool）：仅在 Plan 模式注入；
/// 引擎内部处理，提交方案全文等待用户批准。批准后恢复原模式继续实现，
/// 拒绝后留在计划模式按用户反馈修订方案。
const McpToolDefinition kExitPlanModeToolDefinition = McpToolDefinition(
  name: kToolExitPlanMode,
  description: '提交实现方案并请求退出计划模式。仅在方案已完整（探索完成、路径明确、'
      '关键取舍已确定）时调用；用户批准后才会解锁写类工具开始实现，'
      '拒绝时你会收到反馈并留在计划模式修订方案。',
  inputSchema: {
    'type': 'object',
    'properties': {
      'plan': {
        'type': 'string',
        'description': '完整实现方案（Markdown）：目标、关键改动点（文件/模块级）、'
            '实现步骤、风险与验证方式。这是用户审批的唯一依据，要自洽完整。',
      },
    },
    'required': ['plan'],
  },
);
