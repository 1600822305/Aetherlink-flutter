/// 知识库的「双轨作用域」绑定（设计文档 §3）。
///
/// 把「谁能访问这个库」从「怎么检索」里剥离出来：同一套检索核心，聊天轨道与
/// 未来的智能体轨道只是传入不同的作用域。
///
/// - [chatEnabled]：轨道 B——是否对普通聊天暴露 `kb_*` 工具 / 注入检索。
/// - [agentIds]：轨道 C——绑定到哪些智能体。P0/P1 恒为空数组，仅落库预留，等
///   智能体领域落地后作为 `allowedIds` 过滤条件（设计文档 §9）。
class KnowledgeScope {
  const KnowledgeScope({this.chatEnabled = false, this.agentIds = const []});

  factory KnowledgeScope.fromJson(Map<String, dynamic> json) {
    final rawAgentIds = json['agentIds'];
    return KnowledgeScope(
      chatEnabled: json['chatEnabled'] == true,
      agentIds: rawAgentIds is List
          ? [for (final id in rawAgentIds) id.toString()]
          : const [],
    );
  }

  final bool chatEnabled;
  final List<String> agentIds;

  KnowledgeScope copyWith({bool? chatEnabled, List<String>? agentIds}) {
    return KnowledgeScope(
      chatEnabled: chatEnabled ?? this.chatEnabled,
      agentIds: agentIds ?? this.agentIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'chatEnabled': chatEnabled,
    'agentIds': agentIds,
  };
}
