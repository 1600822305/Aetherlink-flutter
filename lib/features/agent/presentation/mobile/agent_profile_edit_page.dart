// 智能体编辑页（UI 稿 §三）：名称/emoji + 专长提示词 + 工具集勾选 +
// 绑定工作区（已拍板：一个工作区对应一个智能体，就在这里改，话题继承）。
// UI 先行阶段保存写会话内 AgentProfiles provider；接真实现时改走 drift。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/primary_terminal_sheet.dart';

/// [profile] 为 null 时是新建智能体。
Future<void> showAgentProfileEditPage(
  BuildContext context, {
  AgentProfile? profile,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => AgentProfileEditPage(profile: profile),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class AgentProfileEditPage extends ConsumerStatefulWidget {
  const AgentProfileEditPage({this.profile, super.key});

  final AgentProfile? profile;

  @override
  ConsumerState<AgentProfileEditPage> createState() =>
      _AgentProfileEditPageState();
}

class _AgentProfileEditPageState extends ConsumerState<AgentProfileEditPage> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile?.name ?? '',
  );
  late final TextEditingController _emoji = TextEditingController(
    text: widget.profile?.emoji ?? '🤖',
  );
  late final TextEditingController _prompt = TextEditingController(
    text: widget.profile?.systemPrompt ?? '',
  );
  late Set<AgentToolGroup> _tools = {
    ...widget.profile?.tools ?? {AgentToolGroup.fileEditor},
  };
  late String? _workspaceId = widget.profile?.workspaceId;
  late String? _workspaceName = widget.profile?.workspaceName;

  bool get _isNew => widget.profile == null;

  /// 用主终端选择器 + IDE 式目录浏览器新建一个工作区并绑定到本档案；
  /// 不切换当前工作区，各档案可各自绑不同终端并行使用。
  Future<void> _pickWorkspaceViaTerminal() async {
    final workspace = await pickFolderWithTerminalPicker(
      context,
      ref,
      switchTo: false,
    );
    if (workspace == null || !mounted) return;
    setState(() {
      _workspaceId = workspace.id;
      _workspaceName = workspace.name;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    _prompt.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final base =
        widget.profile ??
        AgentProfile(
          id: 'agent-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          emoji: _emoji.text.trim(),
          systemPrompt: _prompt.text.trim(),
          tools: _tools,
        );
    ref
        .read(agentProfilesProvider.notifier)
        .upsert(
          base.copyWith(
            name: name,
            emoji: _emoji.text.trim().isEmpty ? '🤖' : _emoji.text.trim(),
            systemPrompt: _prompt.text.trim(),
            tools: _tools,
            workspaceId: _workspaceId,
            workspaceName: _workspaceName,
          ),
        );
    if (_isNew) {
      ref.read(selectedAgentProfileIdProvider.notifier).select(base.id);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final workspaces = ref.watch(recentWorkspacesViewProvider);
    final canSave = _name.text.trim().isNotEmpty;

    // 顶栏 chrome 与主聊天同款：纸面 surface、无阴影、1px 底分隔线。
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        titleSpacing: 0,
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isNew ? '新建智能体' : '编辑智能体',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _emoji,
                  textAlign: TextAlign.center,
                  maxLength: 2,
                  style: const TextStyle(fontSize: 24),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '名称',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionTitle(
            title: '绑定工作区',
            subtitle: '一个工作区对应一个智能体；话题创建时直接继承',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('不绑定'),
                selected: _workspaceId == null,
                onSelected: (_) => setState(() {
                  _workspaceId = null;
                  _workspaceName = null;
                }),
              ),
              for (final ws in workspaces)
                ChoiceChip(
                  avatar: Icon(
                    LucideIcons.folderTree,
                    size: 14,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                  label: Text(ws.name),
                  selected: _workspaceId == ws.id,
                  onSelected: (_) => setState(() {
                    _workspaceId = ws.id;
                    _workspaceName = ws.name;
                  }),
                ),
              ActionChip(
                avatar: Icon(
                  LucideIcons.folderPlus,
                  size: 14,
                  color: cs.primary,
                ),
                label: const Text('选目录新建绑定…'),
                onPressed: _pickWorkspaceViaTerminal,
              ),
            ],
          ),
          if (workspaces.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '还没有最近打开的工作区，先去工作区页打开一个',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const _SectionTitle(title: '工具集', subtitle: '决定该智能体每轮可见的工具清单'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final g in AgentToolGroup.values)
                FilterChip(
                  label: Text(_toolGroupLabel(g)),
                  selected: _tools.contains(g),
                  onSelected: (v) => setState(() {
                    v ? _tools.add(g) : _tools.remove(g);
                    _tools = {..._tools};
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionTitle(
            title: '专长提示词',
            subtitle: '系统提示第 3 层（档案专长段）；内置基础指南不可覆盖',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _prompt,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: '例如：你是一名资深软件工程师……',
              border: OutlineInputBorder(),
            ),
          ),
          if (widget.profile?.builtin ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '内置预设：可修改配置，不可删除',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _toolGroupLabel(AgentToolGroup g) => switch (g) {
  AgentToolGroup.fileEditor => '文件编辑',
  AgentToolGroup.terminal => '终端',
  AgentToolGroup.webSearch => '网络搜索',
  AgentToolGroup.knowledgeBase => '知识库',
  AgentToolGroup.skills => '技能',
};

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
