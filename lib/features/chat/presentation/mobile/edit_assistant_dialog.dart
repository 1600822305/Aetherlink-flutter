/// 编辑助手 dialog — the port of the web `EditAssistantDialog`
/// (`src/components/TopicManagement/AssistantTab/EditAssistantDialog.tsx`):
/// a full-screen sheet (mobile) / 80vh modal (desktop) with six tabs — 基础 /
/// 提示词 / 参数 / 正则 / 记忆 / 技能.
///
/// The original nests each tab's body in its own scroll inside an 80vh paper;
/// this port keeps the same tab set and instant-swap + horizontal-swipe tab
/// mechanic used elsewhere (MCP 服务器 / 技能管理 pages) and condenses each tab
/// into a single scroll.
///
/// Wired fields (persisted on 保存 via [Assistants.update]): 名称, 系统提示词
/// (+ 预设提示词 picker), 记忆开关, 技能绑定. The heavier surfaces — 头像/聊天壁纸
/// 上传, 模型参数编辑, 正则规则管理, 记忆条目 CRUD — show 「即将支持」 rather than
/// acting (no fake buttons), matching the UI-only milestone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/skills_access.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/parameter_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/agent_prompt_selector.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/parameter_editor.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/custom_parameter.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// Opens the 编辑助手 dialog for [assistant]. Full-screen on mobile, an 80vh
/// modal on wider layouts (web `BackButtonDialog` fullScreen={isMobile}).
Future<void> showEditAssistantDialog(
  BuildContext context,
  Assistant assistant,
) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x80000000),
    useSafeArea: false,
    builder: (_) => _EditAssistantDialog(assistant: assistant),
  );
}

class _EditAssistantDialog extends ConsumerStatefulWidget {
  const _EditAssistantDialog({required this.assistant});

  final Assistant assistant;

  @override
  ConsumerState<_EditAssistantDialog> createState() =>
      _EditAssistantDialogState();
}

class _EditAssistantDialogState extends ConsumerState<_EditAssistantDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 6,
    vsync: this,
  )..addListener(_onTabChanged);
  int _index = 0;
  double _swipeDx = 0;

  late final TextEditingController _nameController = TextEditingController(
    text: widget.assistant.name,
  );
  late final TextEditingController _promptController = TextEditingController(
    text: widget.assistant.systemPrompt ?? '',
  );
  late bool _memoryEnabled = widget.assistant.memoryEnabled ?? false;
  late List<String> _skillIds = List<String>.from(
    widget.assistant.skillIds ?? const <String>[],
  );
  late ParameterSettings _paramSettings = _initParamSettings();
  late final _AssistantParamDelegate _paramDelegate =
      _AssistantParamDelegate((ps) => setState(() => _paramSettings = ps))
        ..attach(_initParamSettings());

  ParameterSettings _initParamSettings() {
    final a = widget.assistant;
    final values = <String, dynamic>{};
    final flags = <String, bool>{};
    if (a.temperature != null) {
      values['temperature'] = a.temperature;
      flags['temperature'] = true;
    }
    if (a.topP != null) {
      values['topP'] = a.topP;
      flags['topP'] = true;
    }
    if (a.maxTokens != null) {
      values['maxTokens'] = a.maxTokens;
      flags['maxTokens'] = true;
    }
    if (a.frequencyPenalty != null) {
      values['frequencyPenalty'] = a.frequencyPenalty;
      flags['frequencyPenalty'] = true;
    }
    if (a.presencePenalty != null) {
      values['presencePenalty'] = a.presencePenalty;
      flags['presencePenalty'] = true;
    }
    final customParams = (a.customParameters ?? const [])
        .map((cp) => <String, dynamic>{
              'name': cp.name,
              'value': cp.value,
              'type': cp.type.name,
              'enabled': true,
            })
        .toList();
    return ParameterSettings(
      values: values,
      enabledFlags: flags,
      customParameters: customParams,
    );
  }

  bool _saving = false;

  void _onTabChanged() {
    if (_tabController.index != _index) {
      setState(() => _index = _tabController.index);
    }
  }

  void _onSwipeEnd() {
    if (_swipeDx.abs() <= 60) return;
    final next = (_tabController.index + (_swipeDx < 0 ? 1 : -1)).clamp(0, 5);
    if (next != _tabController.index) _tabController.animateTo(next);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _nameController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickPreset() async {
    final selected = await showAgentPromptSelector(context);
    if (selected == null || !mounted) return;
    setState(() => _promptController.text = selected);
  }

  void _toggleSkill(String id) {
    setState(() {
      if (_skillIds.contains(id)) {
        _skillIds = _skillIds.where((s) => s != id).toList();
      } else {
        _skillIds = [..._skillIds, id];
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      await ref
          .read(assistantsProvider.notifier)
          .applyEdits(
            widget.assistant.id,
            name: name.isEmpty ? widget.assistant.name : name,
            systemPrompt: _promptController.text.trim(),
            memoryEnabled: _memoryEnabled,
            skillIds: _skillIds,
            paramSettings: _paramSettings,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.maybeOf(context)
          ?..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('保存失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final isMobile = mq.size.width < 600;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(theme, isMobile),
        _tabBar(theme),
        Expanded(
          child: GestureDetector(
            onHorizontalDragStart: (_) => _swipeDx = 0,
            onHorizontalDragUpdate: (d) => _swipeDx += d.delta.dx,
            onHorizontalDragEnd: (_) => _onSwipeEnd(),
            child: IndexedStack(
              index: _index,
              sizing: StackFit.expand,
              children: [
                _BasicTab(
                  assistant: widget.assistant,
                  nameController: _nameController,
                ),
                _PromptTab(
                  controller: _promptController,
                  onPickPreset: _pickPreset,
                ),
                _ParameterTab(
                  settings: _paramSettings,
                  delegate: _paramDelegate,
                ),
                const _ComingSoonTab(
                  icon: LucideIcons.wand2,
                  text: '即将支持：正则规则管理\n(查找替换 / 导入 / 排序)',
                ),
                _MemoryTab(
                  enabled: _memoryEnabled,
                  onChanged: (v) => setState(() => _memoryEnabled = v),
                ),
                _SkillsTab(skillIds: _skillIds, onToggle: _toggleSkill),
              ],
            ),
          ),
        ),
        _actions(theme, isMobile),
      ],
    );

    if (isMobile) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(),
        child: SafeArea(child: body),
      );
    }
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: mq.size.height * 0.8,
        ),
        child: body,
      ),
    );
  }

  // ---- Header ---------------------------------------------------------------

  Widget _header(ThemeData theme, bool isMobile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            iconSize: isMobile ? 26 : 22,
            color: theme.colorScheme.onSurface,
            icon: const Icon(LucideIcons.chevronLeft),
            tooltip: '返回',
          ),
          const SizedBox(width: 4),
          Text(
            '编辑助手',
            style: TextStyle(
              fontSize: isMobile ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Tab bar --------------------------------------------------------------

  Widget _tabBar(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicatorColor: theme.colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: const [
          _IconTab(icon: LucideIcons.settings, label: '基础'),
          _IconTab(icon: LucideIcons.fileText, label: '提示词'),
          _IconTab(icon: LucideIcons.settings2, label: '参数'),
          _IconTab(icon: LucideIcons.wand2, label: '正则'),
          _IconTab(icon: LucideIcons.brain, label: '记忆'),
          _IconTab(icon: LucideIcons.zap, label: '技能'),
        ],
      ),
    );
  }

  // ---- Actions --------------------------------------------------------------

  Widget _actions(ThemeData theme, bool isMobile) {
    return Container(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 12, 16, 16)
          : const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中...' : '保存'),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar item ─────────────────────────────────────────────────────────────

class _IconTab extends StatelessWidget {
  const _IconTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 15), const SizedBox(width: 5), Text(label)],
      ),
    );
  }
}

// ── 基础 ─────────────────────────────────────────────────────────────────────

class _BasicTab extends StatelessWidget {
  const _BasicTab({required this.assistant, required this.nameController});

  final Assistant assistant;
  final TextEditingController nameController;

  String get _avatarText {
    final emoji = assistant.emoji;
    if (emoji != null && emoji.isNotEmpty) return emoji;
    final name = nameController.text;
    if (name.isEmpty) return '助';
    return String.fromCharCodes(name.runes.take(1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _ComingSoonTooltip(
              message: '即将支持：修改头像',
              child: CircleAvatar(
                radius: 30,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                child: Text(
                  _avatarText,
                  style: TextStyle(
                    fontSize: 22,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(theme, '助手名称'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    autofocus: false,
                    style: TextStyle(fontSize: isMobile ? 16 : 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '示例助手',
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
        const SizedBox(height: 24),
        _label(theme, '聊天壁纸'),
        const SizedBox(height: 4),
        Text(
          '助手壁纸优先级高于全局设置',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _ComingSoonTooltip(
          message: '即将支持：上传聊天壁纸',
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.dividerColor,
                style: BorderStyle.solid,
                width: 2,
              ),
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.image,
                  size: 26,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 6),
                Text(
                  '即将支持：上传壁纸',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── 提示词 ────────────────────────────────────────────────────────────────────

class _PromptTab extends StatelessWidget {
  const _PromptTab({required this.controller, required this.onPickPreset});

  final TextEditingController controller;
  final VoidCallback onPickPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '系统提示词',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPickPreset,
                icon: const Icon(LucideIcons.sparkles, size: 16),
                label: const Text('选择预设提示词'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: false,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(fontSize: isMobile ? 16 : 14, height: 1.5),
              decoration: InputDecoration(
                hintText: '请输入系统提示词，定义助手的角色和行为特征...',
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '提示词将作为系统消息发送给 AI，定义助手的角色和行为',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 记忆 ─────────────────────────────────────────────────────────────────────

class _MemoryTab extends StatelessWidget {
  const _MemoryTab({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Row(
            children: [
              Icon(
                LucideIcons.brain,
                size: 20,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '启用记忆功能',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '开启后，助手会记住与你的对话内容',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onChanged),
            ],
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: 16),
          const _ComingSoonNote(text: '即将支持：记忆条目的添加 / 搜索 / 编辑 / 删除'),
        ],
      ],
    );
  }
}

// ── 技能 ─────────────────────────────────────────────────────────────────────

class _SkillsTab extends ConsumerWidget {
  const _SkillsTab({required this.skillIds, required this.onToggle});

  final List<String> skillIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final skills = (ref.watch(skillsProvider).asData?.value ?? const <Skill>[])
        .where((s) => s.enabled)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.zap,
                    size: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '绑定技能',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '选择要绑定到此助手的技能，绑定后技能摘要将注入系统提示词',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (skills.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '暂无可用技能，请先在设置 → 技能管理中启用技能',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final skill in skills) _skillRow(theme, skill),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '已绑定 ${skillIds.length} 个技能',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _skillRow(ThemeData theme, Skill skill) {
    final checked = skillIds.contains(skill.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: checked
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onToggle(skill.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: checked ? theme.colorScheme.primary : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: checked,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (_) => onToggle(skill.id),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  skill.emoji ?? '🔧',
                  style: const TextStyle(fontSize: 18, height: 1),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        skill.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (skill.source == SkillSource.builtin)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Text(
                      '内置',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── shared bits ──────────────────────────────────────────────────────────────

Widget _label(ThemeData theme, String text) => Text(
  text,
  style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: theme.colorScheme.onSurfaceVariant,
  ),
);

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: child,
    );
  }
}

// ─── Parameter tab ─────────────────────────────────────────────────────────

/// Wraps [ParameterEditor] in a scrollable tab body, operating on the
/// local per-assistant [ParameterSettings] instead of the global provider.
class _ParameterTab extends StatelessWidget {
  const _ParameterTab({required this.settings, required this.delegate});

  final ParameterSettings settings;
  final ParameterDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ParameterEditor(
          settings: settings,
          delegate: delegate,
        ),
      ],
    );
  }
}

/// Local [ParameterDelegate] that mutates an in-memory [ParameterSettings] and
/// calls back with the new value so the dialog's [setState] can rebuild the
/// parameter tab.
class _AssistantParamDelegate implements ParameterDelegate {
  _AssistantParamDelegate(this._onChanged);

  final ValueChanged<ParameterSettings> _onChanged;
  ParameterSettings _ps = const ParameterSettings();

  /// Must be called once from the dialog state to sync the initial value.
  void attach(ParameterSettings initial) => _ps = initial;

  @override
  void setParameterValue(String key, Object? value) {
    final next = Map<String, dynamic>.of(_ps.values);
    next[key] = value;
    _ps = _ps.copyWith(values: next);
    _onChanged(_ps);
  }

  @override
  void setParameterEnabled(String key, bool enabled) {
    final next = Map<String, bool>.of(_ps.enabledFlags);
    next[key] = enabled;
    _ps = _ps.copyWith(enabledFlags: next);
    _onChanged(_ps);
  }

  @override
  void addCustomParameter(Map<String, dynamic> param) {
    final next = List<Map<String, dynamic>>.of(_ps.customParameters)..add(param);
    _ps = _ps.copyWith(customParameters: next);
    _onChanged(_ps);
  }

  @override
  void removeCustomParameter(int index) {
    final next = List<Map<String, dynamic>>.of(_ps.customParameters);
    if (index >= 0 && index < next.length) {
      next.removeAt(index);
      _ps = _ps.copyWith(customParameters: next);
      _onChanged(_ps);
    }
  }

  @override
  void updateCustomParameter(int index, Map<String, dynamic> param) {
    final next = List<Map<String, dynamic>>.of(_ps.customParameters);
    if (index >= 0 && index < next.length) {
      next[index] = param;
      _ps = _ps.copyWith(customParameters: next);
      _onChanged(_ps);
    }
  }
}

/// A whole-tab 「即将支持」 placeholder (for 正则) — centered icon + text,
/// so an unfinished tab reads as deliberately deferred, not broken.
class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonNote extends StatelessWidget {
  const _ComingSoonNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Wraps a not-yet-wired affordance so tapping/long-pressing explains it's
/// 「即将支持」 rather than silently doing nothing.
class _ComingSoonTooltip extends StatelessWidget {
  const _ComingSoonTooltip({required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.maybeOf(context)
          ?..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
            ),
          ),
        child: child,
      ),
    );
  }
}
