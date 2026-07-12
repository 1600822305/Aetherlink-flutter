/// 智能体档案（对齐聊天的"助手"）：可配置的专长角色。
/// 设计稿：docs/智能体模式-设计初稿.md §四、docs/智能体模式-UI设计稿-移动端.md §三。
library;

/// 档案可勾选的工具分组，决定该智能体每轮可见的工具清单。
enum AgentToolGroup { fileEditor, terminal, webSearch, knowledgeBase, skills }

/// 一个智能体档案 = 名称/图标 + 专长系统提示段 + 工具集 + 绑定工作区 +
/// 权限偏好。内置预设（编程/网络研究/PPT 文档）不可删可复制。
/// 已拍板：工作区绑在智能体上（一个工作区对应一个智能体），
/// 在智能体设置里改；话题创建时直接继承，不单独选。
class AgentProfile {
  const AgentProfile({
    required this.id,
    required this.name,
    required this.emoji,
    required this.systemPrompt,
    required this.tools,
    this.workspaceId,
    this.workspaceName,
    this.builtin = false,
  });

  final String id;
  final String name;
  final String emoji;

  /// 档案专长段（系统提示第 3 层，见架构稿 §5.2）。
  final String systemPrompt;

  final Set<AgentToolGroup> tools;

  /// 该智能体绑定的工作区；null = 尚未绑定（在智能体设置里选）。
  final String? workspaceId;

  /// 展示用工作区名（UI mock 阶段直存；接真实数据后由 id 派生）。
  final String? workspaceName;

  final bool builtin;
}
