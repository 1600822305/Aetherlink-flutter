import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/mcp_servers_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/skills_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
import 'package:aetherlink_flutter/shared/widgets/app_select_field.dart';

/// The 技能编辑器 page (`/settings/skills/:skillId`), a port of the original
/// `src/pages/Settings/SkillEditor.tsx`. Edits a single skill's 名称 / emoji /
/// 描述 / 指令(SKILL.md) / 触发短语 / 标签 / 关联 MCP 服务器.
///
/// Built-in skills are partially read-only — matching the web, name / emoji /
/// description / trigger phrases / tags are locked, while the instruction body
/// and the MCP-server association stay editable. Saving writes back through the
/// [Skills] controller.
class SkillEditorPage extends ConsumerStatefulWidget {
  const SkillEditorPage({super.key, required this.skillId});

  final String skillId;

  @override
  ConsumerState<SkillEditorPage> createState() => _SkillEditorPageState();
}

class _SkillEditorPageState extends ConsumerState<SkillEditorPage> {
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _triggerInputController = TextEditingController();
  final _tagInputController = TextEditingController();

  List<String> _triggerPhrases = const <String>[];
  List<String> _tags = const <String>[];
  String? _mcpServerId;

  bool _initialized = false;
  Skill? _skill;

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _triggerInputController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _hydrate(Skill skill) {
    _skill = skill;
    _nameController.text = skill.name;
    _emojiController.text = skill.emoji ?? '';
    _descriptionController.text = skill.description;
    _contentController.text = skill.content;
    _triggerPhrases = List<String>.from(skill.triggerPhrases);
    _tags = List<String>.from(skill.tags);
    _mcpServerId = skill.mcpServerId;
    _initialized = true;
  }

  Future<void> _save() async {
    final skill = _skill;
    if (skill == null) return;
    final name = _nameController.text.trim();
    final emoji = _emojiController.text.trim();
    final updated = skill.copyWith(
      name: name.isEmpty ? '未命名技能' : name,
      emoji: emoji.isEmpty ? '🔧' : emoji,
      description: _descriptionController.text.trim(),
      content: _contentController.text,
      triggerPhrases: _triggerPhrases,
      tags: _tags,
      mcpServerId: (_mcpServerId == null || _mcpServerId!.isEmpty)
          ? null
          : _mcpServerId,
    );
    await ref.read(skillsProvider.notifier).save(updated);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('已保存'), duration: Duration(seconds: 2)),
      );
    _back();
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go(AppRouter.skillsPath);

  void _addTrigger() {
    final phrase = _triggerInputController.text.trim();
    if (phrase.isEmpty || _triggerPhrases.contains(phrase)) return;
    setState(() {
      _triggerPhrases = <String>[..._triggerPhrases, phrase];
      _triggerInputController.clear();
    });
  }

  void _addTag() {
    final tag = _tagInputController.text.trim();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() {
      _tags = <String>[..._tags, tag];
      _tagInputController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skillsAsync = ref.watch(
      skillsProvider.select(
        (async) => async.whenData(
          (list) => list.where((s) => s.id == widget.skillId).firstOrNull,
        ),
      ),
    );

    return skillsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('技能编辑')),
        body: const Center(child: Text('加载技能失败')),
      ),
      data: (skill) {
        if (skill == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: _back,
              ),
              title: const Text('技能编辑'),
            ),
            body: const Center(child: Text('技能不存在')),
          );
        }
        if (!_initialized) _hydrate(skill);
        return _buildEditor(theme, skill);
      },
    );
  }

  Widget _buildEditor(ThemeData theme, Skill skill) {
    final isBuiltin = skill.source == SkillSource.builtin;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: _back,
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: ListenableBuilder(
          listenable: Listenable.merge([_emojiController, _nameController]),
          builder: (_, _) {
            final emoji = _emojiController.text.isEmpty
                ? skill.emoji ?? ''
                : _emojiController.text;
            return Text(
              '$emoji ${_nameController.text}'.trim(),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ModelTonalButton(
              label: '保存',
              icon: LucideIcons.save,
              onPressed: _save,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _basicInfoCard(theme, isBuiltin),
          const SizedBox(height: 12),
          _instructionsCard(theme),
          const SizedBox(height: 12),
          _triggerCard(theme, isBuiltin),
          const SizedBox(height: 12),
          _tagsCard(theme, isBuiltin),
          const SizedBox(height: 12),
          _mcpCard(theme),
          const SizedBox(height: 12),
          _metaCard(theme, skill),
        ],
      ),
    );
  }

  Widget _basicInfoCard(ThemeData theme, bool isBuiltin) {
    return ModelSettingsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(icon: LucideIcons.zap, title: '基本信息'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: ModelFormField(
                  label: 'emoji',
                  controller: _emojiController,
                  enabled: !isBuiltin,
                  hint: '🔧',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ModelFormField(
                  label: '技能名称',
                  controller: _nameController,
                  enabled: !isBuiltin,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ModelFormField(
            label: '描述',
            controller: _descriptionController,
            enabled: !isBuiltin,
            maxLines: 3,
          ),
          if (isBuiltin) ...[
            const SizedBox(height: 8),
            Text(
              '内置技能的基础信息只读，可编辑指令内容与关联工具',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _instructionsCard(ThemeData theme) {
    return ModelSettingsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(icon: LucideIcons.fileText, title: '技能指令'),
          const SizedBox(height: 12),
          ModelFormField(
            label: 'SKILL.md',
            controller: _contentController,
            maxLines: 10,
            hint: '编写技能的指令内容（Markdown），AI 通过 read_skill 工具按需读取',
          ),
          const SizedBox(height: 6),
          Text(
            '指令越具体，AI 越能精准执行；支持 Markdown 格式',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _triggerCard(ThemeData theme, bool isBuiltin) {
    return ModelSettingsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(icon: LucideIcons.messageSquare, title: '触发短语'),
          const SizedBox(height: 12),
          if (!isBuiltin)
            ModelFormField(
              label: '添加触发短语',
              controller: _triggerInputController,
              hint: '输入后回车添加',
              onSubmitted: (_) => _addTrigger(),
              suffixIcon: IconButton(
                icon: const Icon(LucideIcons.plus, size: 18),
                onPressed: _addTrigger,
              ),
            ),
          const SizedBox(height: 8),
          _chips(
            theme,
            _triggerPhrases,
            empty: '暂无触发短语',
            onDelete: isBuiltin
                ? null
                : (p) => setState(
                    () => _triggerPhrases = _triggerPhrases
                        .where((e) => e != p)
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tagsCard(ThemeData theme, bool isBuiltin) {
    return ModelSettingsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(icon: LucideIcons.tag, title: '标签'),
          const SizedBox(height: 12),
          if (!isBuiltin)
            ModelFormField(
              label: '添加标签',
              controller: _tagInputController,
              hint: '输入后回车添加',
              onSubmitted: (_) => _addTag(),
              suffixIcon: IconButton(
                icon: const Icon(LucideIcons.plus, size: 18),
                onPressed: _addTag,
              ),
            ),
          const SizedBox(height: 8),
          _chips(
            theme,
            _tags,
            empty: '暂无标签',
            outlined: true,
            onDelete: isBuiltin
                ? null
                : (t) => setState(
                    () => _tags = _tags.where((e) => e != t).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _mcpCard(ThemeData theme) {
    final serversAsync = ref.watch(mcpServersProvider);
    final servers = serversAsync.asData?.value ?? const [];
    return ModelSettingsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(icon: LucideIcons.plug, title: '关联 MCP 服务器'),
          const SizedBox(height: 12),
          AppSelectField<String>(
            value:
                (_mcpServerId != null &&
                    servers.any((s) => s.id == _mcpServerId))
                ? _mcpServerId!
                : '',
            sheetTitle: '关联 MCP 服务器',
            options: [
              const AppSelectOption(value: '', label: '无'),
              for (final server in servers)
                AppSelectOption(
                  value: server.id,
                  label: server.name.isEmpty ? server.id : server.name,
                ),
            ],
            onChanged: (v) => setState(() => _mcpServerId = v),
          ),
          const SizedBox(height: 6),
          Text(
            '关联后，使用该技能时可自动启用对应的 MCP 工具',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaCard(ThemeData theme, Skill skill) {
    final source = switch (skill.source) {
      SkillSource.builtin => '内置',
      SkillSource.user => '自定义',
      SkillSource.community => '社区',
    };
    final parts = <String>[
      '来源：$source',
      if (skill.version != null) '版本：${skill.version}',
      if (skill.author != null) '作者：${skill.author}',
    ];
    return Text(
      parts.join('  |  '),
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _chips(
    ThemeData theme,
    List<String> values, {
    required String empty,
    bool outlined = false,
    void Function(String)? onDelete,
  }) {
    if (values.isEmpty) {
      return Text(
        empty,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final value in values)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
            decoration: BoxDecoration(
              color: outlined
                  ? null
                  : theme.colorScheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: outlined ? Border.all(color: theme.dividerColor) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 2),
                  InkWell(
                    onTap: () => onDelete(value),
                    borderRadius: BorderRadius.circular(8),
                    child: Icon(
                      LucideIcons.x,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else
                  const SizedBox(width: 6),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurface),
        const SizedBox(width: 8),
        ModelSectionTitle(title),
      ],
    );
  }
}
