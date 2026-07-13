// 智能体编辑页（UI 稿 §三）：名称/emoji + 专长提示词 + 工具集勾选 +
// 绑定工作区（已拍板：一个工作区对应一个智能体，就在这里改，话题继承）。
// UI 风格对齐聊天的「编辑助手」dialog（edit_assistant_dialog.dart）：
// 头像圈 + 名称行、onSurfaceVariant 小节标签、浅色圆角卡片分节、
// 紧凑 chips、底部 取消/保存 操作条。

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
  late String _emoji = widget.profile?.emoji ?? '🤖';
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

  Future<void> _editEmoji() async {
    final controller = TextEditingController(text: _emoji);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('头像 emoji', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.center,
          maxLength: 2,
          style: const TextStyle(fontSize: 28),
          decoration: InputDecoration(
            counterText: '',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    setState(() => _emoji = result.isEmpty ? '🤖' : result);
  }

  @override
  void dispose() {
    _name.dispose();
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
          emoji: _emoji,
          systemPrompt: _prompt.text.trim(),
          tools: _tools,
        );
    ref
        .read(agentProfilesProvider.notifier)
        .upsert(
          base.copyWith(
            name: name,
            emoji: _emoji,
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
    final canSave = _name.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            _header(theme),
            Expanded(child: _body(theme, cs)),
            _actions(theme, canSave),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            iconSize: 26,
            color: theme.colorScheme.onSurface,
            icon: const Icon(LucideIcons.chevronLeft),
            tooltip: '返回',
          ),
          const SizedBox(width: 4),
          Text(
            _isNew ? '创建智能体' : '编辑智能体',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (widget.profile?.builtin ?? false)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Text(
                '内置预设',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(ThemeData theme, ColorScheme cs) {
    final workspaces = ref.watch(recentWorkspacesViewProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 头像 + 名称（编辑助手 dialog 基础 tab 同款布局）。
        Row(
          children: [
            GestureDetector(
              onTap: _editEmoji,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Text(_emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: const Icon(
                        LucideIcons.pencil,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(theme, '智能体名称'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _name,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '示例智能体',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _label(theme, '绑定工作区'),
        const SizedBox(height: 4),
        Text(
          '一个工作区对应一个智能体；话题创建时直接继承',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 0,
                children: [
                  ChoiceChip(
                    label: const Text('不绑定'),
                    labelStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                    selected: _workspaceId == null,
                    selectedColor: cs.primary.withValues(alpha: 0.12),
                    onSelected: (_) => setState(() {
                      _workspaceId = null;
                      _workspaceName = null;
                    }),
                  ),
                  for (final ws in workspaces)
                    ChoiceChip(
                      avatar: Icon(
                        LucideIcons.folderTree,
                        size: 13,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                      label: Text(ws.name),
                      labelStyle: const TextStyle(fontSize: 12),
                      visualDensity: VisualDensity.compact,
                      selected: _workspaceId == ws.id,
                      selectedColor: cs.primary.withValues(alpha: 0.12),
                      onSelected: (_) => setState(() {
                        _workspaceId = ws.id;
                        _workspaceName = ws.name;
                      }),
                    ),
                  ActionChip(
                    avatar: Icon(
                      LucideIcons.folderPlus,
                      size: 13,
                      color: cs.primary,
                    ),
                    label: const Text('选目录新建绑定…'),
                    labelStyle: TextStyle(fontSize: 12, color: cs.primary),
                    visualDensity: VisualDensity.compact,
                    onPressed: _pickWorkspaceViaTerminal,
                  ),
                ],
              ),
              if (workspaces.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '还没有最近打开的工作区，先去工作区页打开一个',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _label(theme, '工具集'),
        const SizedBox(height: 4),
        Text(
          '决定该智能体每轮可见的工具清单',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _Card(
          child: Wrap(
            spacing: 6,
            runSpacing: 0,
            children: [
              for (final g in AgentToolGroup.values)
                FilterChip(
                  label: Text(_toolGroupLabel(g)),
                  labelStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                  selected: _tools.contains(g),
                  selectedColor: cs.primary.withValues(alpha: 0.12),
                  onSelected: (v) => setState(() {
                    v ? _tools.add(g) : _tools.remove(g);
                    _tools = {..._tools};
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _label(theme, '专长提示词'),
        const SizedBox(height: 4),
        Text(
          '系统提示第 3 层（档案专长段）；内置基础指南不可覆盖',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _prompt,
          minLines: 5,
          maxLines: 12,
          style: const TextStyle(fontSize: 14, height: 1.5),
          decoration: InputDecoration(
            hintText: '例如：你是一名资深软件工程师……',
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _actions(ThemeData theme, bool canSave) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: canSave ? _save : null,
            child: Text(_isNew ? '创建' : '保存'),
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

Widget _label(ThemeData theme, String text) => Text(
  text,
  style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: theme.colorScheme.onSurfaceVariant,
  ),
);

/// 浅色圆角分节卡片（编辑助手 dialog `_Card` 同款）。
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: child,
    );
  }
}
