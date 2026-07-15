/// 内置预设智能体档案（UI 稿 §三：编程/网络研究/PPT 文档，不可删可复制）。
/// 工作区绑定由用户在智能体设置里自行选择，预设不预绑。
library;

import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';

const List<AgentProfile> kBuiltinAgentProfiles = [
  AgentProfile(
    id: 'agent-coding',
    name: '编程',
    emoji: '💻',
    systemPrompt: '你是一名资深软件工程师……',
    tools: {
      AgentToolGroup.fileEditor,
      AgentToolGroup.terminal,
      AgentToolGroup.skills,
    },
    builtin: true,
  ),
  AgentProfile(
    id: 'agent-research',
    name: '网络研究',
    emoji: '🔍',
    systemPrompt: '你是一名调研分析师……',
    tools: {
      AgentToolGroup.webSearch,
      AgentToolGroup.knowledgeBase,
      AgentToolGroup.fileEditor,
    },
    builtin: true,
  ),
  AgentProfile(
    id: 'agent-docs',
    name: 'PPT 文档',
    emoji: '📊',
    systemPrompt: '你是一名文档/演示专家……',
    tools: {AgentToolGroup.fileEditor, AgentToolGroup.skills},
    builtin: true,
  ),
];
