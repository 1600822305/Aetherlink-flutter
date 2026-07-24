// Hooks 设置页共享的展示元数据：类型/事件徽标、阶段分组、matcher 建议。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';

/// hook 类型的展示元数据（徽标/表单文案共用）。
typedef HookTypeMeta = ({String label, Color color, IconData icon});

HookTypeMeta hookTypeMetaOf(AgentHookType type) => switch (type) {
  AgentHookType.command => (
    label: '命令',
    color: Colors.blueGrey,
    icon: LucideIcons.terminal,
  ),
  AgentHookType.prompt => (
    label: '提示词',
    color: Colors.indigo,
    icon: LucideIcons.sparkles,
  ),
  AgentHookType.http => (
    label: 'HTTP',
    color: Colors.green,
    icon: LucideIcons.globe,
  ),
  AgentHookType.agent => (
    label: '智能体',
    color: Colors.deepPurple,
    icon: LucideIcons.bot,
  ),
};

/// 类型徽标（图标 + 文字，不只靠颜色区分）。
class HookTypeBadge extends StatelessWidget {
  const HookTypeBadge({super.key, required this.type});

  final AgentHookType type;

  @override
  Widget build(BuildContext context) {
    final meta = hookTypeMetaOf(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 11, color: meta.color),
          const SizedBox(width: 3),
          Text(
            meta.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: meta.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 生命周期事件的展示元数据（阶段分组对标 LiveAgent）。
typedef HookEventMeta = ({
  String stage,
  Color color,
  String title,
  String description,
  bool canBlock,
});

HookEventMeta hookEventMetaOf(AgentHookEvent event) => switch (event) {
  AgentHookEvent.taskStart => (
    stage: 'AGENT',
    color: Colors.purple,
    title: 'taskStart',
    description: '任务启动/续跑时触发。',
    canBlock: false,
  ),
  AgentHookEvent.userPromptSubmit => (
    stage: 'AGENT',
    color: Colors.purple,
    title: 'userPromptSubmit',
    description:
        '用户消息进入任务前触发；hook 可拦截本条消息，'
        '也可注入 additionalContext 上下文。',
    canBlock: true,
  ),
  AgentHookEvent.turnStart => (
    stage: 'TURN',
    color: Colors.blue,
    title: 'turnStart',
    description: '每轮开始（模型调用前）触发。',
    canBlock: false,
  ),
  AgentHookEvent.preToolUse => (
    stage: 'TOOL',
    color: Colors.orange,
    title: 'preToolUse',
    description:
        '工具执行前触发；hook 可拦截本次调用，'
        '也可裁决免审 / 强制审批。',
    canBlock: true,
  ),
  AgentHookEvent.postToolUse => (
    stage: 'TOOL',
    color: Colors.orange,
    title: 'postToolUse',
    description: '工具成功执行后触发；hook 反馈会回填给模型（如格式化报错）。',
    canBlock: true,
  ),
  AgentHookEvent.postToolUseFailure => (
    stage: 'TOOL',
    color: Colors.orange,
    title: 'postToolUseFailure',
    description: '工具执行失败后触发；hook 反馈会回填给模型（如失败原因分析）。',
    canBlock: true,
  ),
  AgentHookEvent.permissionRequest => (
    stage: 'TOOL',
    color: Colors.orange,
    title: 'permissionRequest',
    description:
        '审批弹窗弹出前触发（仅本要弹审批时）；hook 可免审放行、'
        '强制拒绝或照常审批（越工作区 root 的命令不可免审）。',
    canBlock: true,
  ),
  AgentHookEvent.permissionDenied => (
    stage: 'TOOL',
    color: Colors.orange,
    title: 'permissionDenied',
    description:
        '用户拒绝审批后触发（观测型，不阻断）；拒绝原因经 '
        'tool_response 传入，可用于记录/通知。',
    canBlock: false,
  ),
  AgentHookEvent.notification => (
    stage: 'TOOL',
    color: Colors.orange,
    title: 'notification',
    description:
        '需要用户注意时触发（审批挂起 / 提问等待；观测型，不阻断）；'
        '可接外部通知。matcher 匹配通知类型（approval / question）。',
    canBlock: false,
  ),
  AgentHookEvent.fileChanged => (
    stage: 'TOOL',
    color: Colors.orange,
    title: 'fileChanged',
    description:
        '工作区文件变更时触发（去抖后；观测型，不阻断）。'
        'matcher 匹配变更类型（created / modified / deleted / moved），'
        'pattern 匹配文件路径；路径经 file_path、变更类型经 event 传入。',
    canBlock: false,
  ),
  AgentHookEvent.turnEnd => (
    stage: 'TURN',
    color: Colors.blue,
    title: 'turnEnd',
    description: '每轮结束（本轮工具全部执行完）触发。',
    canBlock: false,
  ),
  AgentHookEvent.stop => (
    stage: 'AGENT',
    color: Colors.purple,
    title: 'stop',
    description: '任务收尾前触发；hook 可阻止收尾并要求继续。',
    canBlock: true,
  ),
  AgentHookEvent.subagentStart => (
    stage: 'SUBAGENT',
    color: Colors.teal,
    title: 'subagentStart',
    description: '子智能体启动时触发。',
    canBlock: false,
  ),
  AgentHookEvent.subagentStop => (
    stage: 'SUBAGENT',
    color: Colors.teal,
    title: 'subagentStop',
    description: '子智能体收尾前触发；hook 可阻止收尾并要求继续。',
    canBlock: true,
  ),
  AgentHookEvent.taskEnd => (
    stage: 'AGENT',
    color: Colors.purple,
    title: 'taskEnd',
    description: '主任务正常完成后触发。',
    canBlock: false,
  ),
  AgentHookEvent.preCompact => (
    stage: 'AGENT',
    color: Colors.purple,
    title: 'preCompact',
    description:
        '上下文压缩前触发（观测型，不阻断）；matcher 匹配触发'
        '方式（目前仅 auto）。',
    canBlock: false,
  ),
  AgentHookEvent.postCompact => (
    stage: 'AGENT',
    color: Colors.purple,
    title: 'postCompact',
    description:
        '上下文压缩后触发（观测型，不阻断）；压缩摘要经 '
        'tool_response 传入；matcher 匹配触发方式（目前仅 auto）。',
    canBlock: false,
  ),
};

/// 添加区的阶段分组顺序（同阶段事件聚在一起，与枚举顺序解耦）。
const List<(String, List<AgentHookEvent>)> kHookStageGroups = [
  (
    'AGENT 阶段',
    [
      AgentHookEvent.taskStart,
      AgentHookEvent.userPromptSubmit,
      AgentHookEvent.stop,
      AgentHookEvent.taskEnd,
      AgentHookEvent.preCompact,
      AgentHookEvent.postCompact,
    ],
  ),
  ('TURN 阶段', [AgentHookEvent.turnStart, AgentHookEvent.turnEnd]),
  (
    'TOOL 阶段',
    [
      AgentHookEvent.preToolUse,
      AgentHookEvent.postToolUse,
      AgentHookEvent.postToolUseFailure,
      AgentHookEvent.permissionRequest,
      AgentHookEvent.permissionDenied,
      AgentHookEvent.notification,
      AgentHookEvent.fileChanged,
    ],
  ),
  ('SUBAGENT 阶段', [AgentHookEvent.subagentStart, AgentHookEvent.subagentStop]),
];

/// 常见工具名建议（matcher 快捷填入；仍可自由输入）。
const List<String> kHookMatcherSuggestions = [
  '*',
  'terminal_execute',
  'terminal_*',
  'write',
  'edit',
  'read_file',
  'search_files',
  'delete_file',
  'web_search',
  'mcp:*',
];
