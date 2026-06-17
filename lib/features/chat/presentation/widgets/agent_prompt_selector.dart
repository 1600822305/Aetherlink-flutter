import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/agent_prompt.dart';

/// Opens the 智能体提示词 preset picker and resolves to the chosen preset's
/// `content`, or `null` if cancelled. 1:1 port of the web `AgentPromptSelector`
/// (`src/components/AgentPromptSelector/index.tsx`).
Future<String?> showAgentPromptSelector(BuildContext context) {
  return showDialog<String>(
    context: context,
    // MUI default modal scrim: rgba(0, 0, 0, 0.5).
    barrierColor: const Color(0x80000000),
    builder: (_) => const _AgentPromptSelectorDialog(),
  );
}

class _AgentPromptSelectorDialog extends StatefulWidget {
  const _AgentPromptSelectorDialog();

  @override
  State<_AgentPromptSelectorDialog> createState() =>
      _AgentPromptSelectorDialogState();
}

class _AgentPromptSelectorDialogState
    extends State<_AgentPromptSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  final List<AgentPromptCategory> _categories = getAgentPromptCategories();
  final Set<String> _expanded = <String>{'general'};
  AgentPrompt? _selected;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirm() {
    final selected = _selected;
    if (selected != null) Navigator.of(context).pop(selected.content);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final query = _query.trim();
    final results = query.isEmpty
        ? const <AgentPrompt>[]
        : searchAgentPrompts(query);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SizedBox(
          // Web: Paper height 80vh.
          height: mq.size.height * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _title(theme),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _searchField(theme),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: query.isNotEmpty
                              ? _searchSection(theme, results)
                              : _categorySection(theme),
                        ),
                      ),
                      if (_selected != null) _preview(theme, _selected!),
                    ],
                  ),
                ),
              ),
              _actions(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Title ----------------------------------------------------------------

  Widget _title(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '选择智能体提示词',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            iconSize: 20,
            color: theme.colorScheme.onSurfaceVariant,
            icon: const Icon(LucideIcons.x),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  // ---- Search ---------------------------------------------------------------

  Widget _searchField(ThemeData theme) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        hintText: '搜索提示词...',
        prefixIcon: Icon(
          LucideIcons.search,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ---- Search results -------------------------------------------------------

  Widget _searchSection(ThemeData theme, List<AgentPrompt> results) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '搜索结果 (${results.length})',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        if (results.isEmpty)
          Text(
            '没有找到匹配的提示词',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final prompt in results) _promptItem(theme, prompt),
      ],
    );
  }

  // ---- Categories -----------------------------------------------------------

  Widget _categorySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '提示词类别',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        for (final category in _categories) _category(theme, category),
      ],
    );
  }

  Widget _category(ThemeData theme, AgentPromptCategory category) {
    final expanded = _expanded.contains(category.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (expanded) {
                _expanded.remove(category.id);
              } else {
                _expanded.add(category.id);
              }
            }),
            child: ColoredBox(
              color: const Color(0x05000000),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${category.emoji} ${category.name}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${category.prompts.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, thickness: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (final prompt in category.prompts)
                    _promptItem(theme, prompt),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---- Prompt item ----------------------------------------------------------

  Widget _promptItem(ThemeData theme, AgentPrompt prompt) {
    final selected = _selected?.id == prompt.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _selected = prompt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.dividerColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${prompt.emoji} ${prompt.name}',
                  style: TextStyle(
                    fontSize: 13.6,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prompt.description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (prompt.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 2.4,
                    runSpacing: 2.4,
                    children: [for (final tag in prompt.tags) _tag(theme, tag)],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(ThemeData theme, String label) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 3.2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.6,
          height: 1,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  // ---- Selected preview -----------------------------------------------------

  Widget _preview(ThemeData theme, AgentPrompt prompt) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary, width: 2),
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '已选择: ${prompt.emoji} ${prompt.name}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: SingleChildScrollView(
              child: Text(
                prompt.content,
                style: TextStyle(
                  fontSize: 13.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Actions --------------------------------------------------------------

  Widget _actions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _selected == null ? null : _confirm,
            child: const Text('使用此提示词'),
          ),
        ],
      ),
    );
  }
}
