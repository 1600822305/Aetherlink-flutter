import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';

/// Creates a new memory from the editor sheet's fields (used by both the
/// 全局记忆 and 助手私有记忆 list pages).
typedef MemoryCreate = Future<void> Function({
  required String content,
  required MemoryType type,
  String? category,
  double importance,
});

/// A scope-agnostic memory management screen: search field + list of cards with
/// manual add / edit / delete and an empty state. Both the 全局记忆 page and the
/// per-assistant 私有记忆 page render this, supplying their own Riverpod-backed
/// data ([items]) and mutation callbacks — the only differences are the title
/// and the empty/search copy.
class MemoryListView extends StatefulWidget {
  const MemoryListView({
    super.key,
    required this.title,
    required this.searchHint,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.items,
    required this.onQueryChanged,
    required this.onCreate,
    required this.onSave,
    required this.onDelete,
  });

  final String title;
  final String searchHint;
  final String emptyTitle;
  final String emptySubtitle;
  final AsyncValue<List<MemoryItem>> items;
  final ValueChanged<String> onQueryChanged;
  final MemoryCreate onCreate;
  final Future<void> Function(MemoryItem item) onSave;
  final Future<void> Function(String id) onDelete;

  @override
  State<MemoryListView> createState() => _MemoryListViewState();
}

class _MemoryListViewState extends State<MemoryListView> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    widget.onQueryChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
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
            onPressed: () => context.pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              icon: const Icon(LucideIcons.plus, size: 22),
              color: theme.colorScheme.primary,
              tooltip: '新增记忆',
              onPressed: () => _openEditor(context),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchField(
            controller: _searchController,
            hint: widget.searchHint,
            onChanged: _onQueryChanged,
          ),
          Expanded(
            child: widget.items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  '加载失败：$e',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyState(
                    searching: _query.trim().isNotEmpty,
                    title: widget.emptyTitle,
                    subtitle: widget.emptySubtitle,
                    onAdd: () => _openEditor(context),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => MemoryCard(
                    item: items[i],
                    onTap: () => _openEditor(context, existing: items[i]),
                    onDelete: () => _confirmDelete(context, items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {MemoryItem? existing}) async {
    final result = await showMemoryEditor(context, existing: existing);
    if (result == null) return;
    if (existing == null) {
      await widget.onCreate(
        content: result.content,
        type: result.type,
        category: result.category,
        importance: result.importance,
      );
    } else {
      await widget.onSave(
        existing.copyWith(
          content: result.content,
          type: result.type,
          category: result.category,
          importance: result.importance,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, MemoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记忆'),
        content: const Text('删除后将不再用于对话注入。确定删除这条记忆吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await widget.onDelete(item.id);
    }
  }
}

// =============================================================================
// Search field
// =============================================================================

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          prefixIcon: const Icon(LucideIcons.search, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          filled: true,
          fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Memory card
// =============================================================================

/// A memory card: content preview, type/category/time chips and an edit/delete
/// menu. Shared by the 全局记忆 / 助手私有记忆 list pages and the 搜索全部记忆 page.
/// The latter passes [scopeChip] to label which bucket a row belongs to (the
/// per-scope pages omit it since the whole page is one scope).
class MemoryCard extends StatelessWidget {
  const MemoryCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
    this.scopeChip,
  });

  final MemoryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Widget? scopeChip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.35,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (scopeChip != null) scopeChip!,
                        _TypeChip(type: item.type),
                        if (item.category != null && item.category!.isNotEmpty)
                          _MetaChip(label: item.category!),
                        _MetaChip(label: _relativeTime(item.createdAt)),
                        if (item.accessCount > 0) _HitChip(item: item),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  LucideIcons.ellipsisVertical,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (v) {
                  if (v == 'edit') onTap();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeTime(int epochMs) {
    if (epochMs <= 0) return '';
    final now = DateTime.now();
    final t = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final MemoryType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSemantic = type == MemoryType.semantic;
    final color = isSemantic ? const Color(0xFF6366F1) : const Color(0xFF0EA5E9);
    final label = isSemantic ? '语义' : '情景';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// =============================================================================
// Empty state
// =============================================================================

/// Eval chip: how many times this memory was injected via retrieval and when it
/// was last recalled. Only shown once `accessCount > 0`.
class _HitChip extends StatelessWidget {
  const _HitChip({required this.item});

  final MemoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = Color(0xFF16A34A);
    final last = item.lastAccessedAt;
    final label = last != null && last > 0
        ? '命中 ${item.accessCount} 次 · ${MemoryCard._relativeTime(last)}'
        : '命中 ${item.accessCount} 次';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.target, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.searching,
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  final bool searching;
  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? LucideIcons.searchX : LucideIcons.brain,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 14),
            Text(
              searching ? '没有匹配的记忆' : title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              searching ? '换个关键词试试' : subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!searching) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('新增记忆'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Add / edit bottom sheet
// =============================================================================

/// The fields collected by [showMemoryEditor]'s bottom sheet, applied by the
/// caller to either create a new memory or copy onto an existing one.
class MemoryEditorResult {
  const MemoryEditorResult({
    required this.content,
    required this.type,
    required this.category,
    required this.importance,
  });

  final String content;
  final MemoryType type;
  final String? category;
  final double importance;
}

/// Opens the add/edit memory bottom sheet, returning the collected fields or
/// null when dismissed. Pass [existing] to pre-fill for editing.
Future<MemoryEditorResult?> showMemoryEditor(
  BuildContext context, {
  MemoryItem? existing,
}) {
  return showModalBottomSheet<MemoryEditorResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MemoryEditorSheet(existing: existing),
  );
}

String? _normalizeCategory(String raw) {
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class MemoryEditorSheet extends StatefulWidget {
  const MemoryEditorSheet({super.key, this.existing});

  final MemoryItem? existing;

  @override
  State<MemoryEditorSheet> createState() => _MemoryEditorSheetState();
}

class _MemoryEditorSheetState extends State<MemoryEditorSheet> {
  late final TextEditingController _content;
  late final TextEditingController _category;
  late MemoryType _type;
  late double _importance;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _content = TextEditingController(text: e?.content ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _type = e?.type ?? MemoryType.semantic;
    _importance = e?.importance ?? 0.5;
  }

  @override
  void dispose() {
    _content.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEdit ? '编辑记忆' : '新增记忆',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _content,
              autofocus: !isEdit,
              maxLines: 4,
              minLines: 3,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
              decoration: InputDecoration(
                hintText: '记忆内容，例如：用户是素食者，不吃肉',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '类型',
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<MemoryType>(
              segments: const [
                ButtonSegment(
                  value: MemoryType.semantic,
                  label: Text('语义'),
                  icon: Icon(LucideIcons.lightbulb, size: 16),
                ),
                ButtonSegment(
                  value: MemoryType.episodic,
                  label: Text('情景'),
                  icon: Icon(LucideIcons.clock, size: 16),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _category,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                labelText: '分类（可选）',
                hintText: '例如：饮食偏好',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '重要性',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _importance,
                    divisions: 10,
                    label: _importance.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _importance = v),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    _importance.toStringAsFixed(1),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (_content.text.trim().isEmpty) return;
                      Navigator.of(context).pop(
                        MemoryEditorResult(
                          content: _content.text,
                          type: _type,
                          category: _normalizeCategory(_category.text),
                          importance: _importance,
                        ),
                      );
                    },
                    child: Text(isEdit ? '保存' : '添加'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
