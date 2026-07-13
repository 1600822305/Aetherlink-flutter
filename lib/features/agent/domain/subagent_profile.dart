/// 自定义子代理档案（初稿 §5.5 P2 子代理 v2，对标 Cursor
/// `.cursor/agents/*.md`）：markdown 文件定义一个可派发的子代理——
/// frontmatter 给元信息（name/description/readonly），正文即系统提示。
library;

/// 一个已解析的自定义子代理档案。
class AgentSubagentProfile {
  const AgentSubagentProfile({
    required this.name,
    required this.description,
    required this.readonly,
    required this.systemPrompt,
  });

  /// 派发时 spawn_subagent 的 type 填这个名字。
  final String name;

  /// 一句话说明（注入父级系统提示，帮模型决定何时委派）。
  final String description;

  /// 只读档案跑 Ask 只读约束零审批；非只读沿用父模式 + 现有审批链。
  final bool readonly;

  /// markdown 正文：子代理的系统提示。
  final String systemPrompt;
}

/// 解析 markdown 档案。frontmatter 为可选的 `---` 包围块，按行解析
/// `key: value`（不支持嵌套 YAML）；name 缺省取文件名（去 .md）。
/// 正文为空且无 description 时视为无效档案，返回 null。
AgentSubagentProfile? parseSubagentProfileMarkdown(
  String fileName,
  String content,
) {
  var name = fileName.endsWith('.md')
      ? fileName.substring(0, fileName.length - 3)
      : fileName;
  var description = '';
  var readonly = true;
  var body = content;

  final lines = content.split('\n');
  if (lines.isNotEmpty && lines.first.trim() == '---') {
    final end = lines.indexWhere((l) => l.trim() == '---', 1);
    if (end > 0) {
      for (final line in lines.sublist(1, end)) {
        final sep = line.indexOf(':');
        if (sep <= 0) continue;
        final key = line.substring(0, sep).trim();
        final value = line.substring(sep + 1).trim();
        switch (key) {
          case 'name':
            if (value.isNotEmpty) name = value;
          case 'description':
            description = value;
          case 'readonly':
            readonly = value.toLowerCase() != 'false';
        }
      }
      body = lines.sublist(end + 1).join('\n');
    }
  }

  final prompt = body.trim();
  if (name.trim().isEmpty || (prompt.isEmpty && description.isEmpty)) {
    return null;
  }
  return AgentSubagentProfile(
    name: name.trim(),
    description: description,
    readonly: readonly,
    systemPrompt: prompt,
  );
}
