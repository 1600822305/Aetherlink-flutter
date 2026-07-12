/// 智能体档案（对齐聊天的"助手"）：可配置的专长角色。
/// 设计稿：docs/智能体模式-设计初稿.md §四、docs/智能体模式-UI设计稿-移动端.md §三。
library;

/// 档案可勾选的工具分组，决定该智能体每轮可见的工具清单。
enum AgentToolGroup { fileEditor, terminal, webSearch, knowledgeBase, skills }

/// 一个智能体档案 = 名称/图标 + 专长系统提示段 + 工具集 + 默认工作区 +
/// 权限偏好。内置预设（编程/网络研究/PPT 文档）不可删可复制。
class AgentProfile {
  const AgentProfile({
    required this.id,
    required this.name,
    required this.emoji,
    required this.systemPrompt,
    required this.tools,
    this.defaultWorkspaceId,
    this.builtin = false,
  });

  final String id;
  final String name;
  final String emoji;

  /// 档案专长段（系统提示第 3 层，见架构稿 §5.2）。
  final String systemPrompt;

  final Set<AgentToolGroup> tools;

  /// 新建话题时预选的工作区；null = 每次新建时选。
  final String? defaultWorkspaceId;

  final bool builtin;
}
