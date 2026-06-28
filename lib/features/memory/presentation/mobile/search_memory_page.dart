import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/assistants_access.dart';
import 'package:aetherlink_flutter/features/memory/application/memory_providers.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';
import 'package:aetherlink_flutter/features/memory/presentation/mobile/memory_list_view.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';

/// 搜索全部记忆 (记忆 → 搜索全部记忆) — a cross-scope search over chat-global plus
/// every assistant's private memories. Each result carries a scope chip (全局 or
/// the owning assistant's name) so a single list can mix buckets. Editing and
/// deleting reuse the shared [showMemoryEditor]/[MemoryCard]; the page can't
/// create memories (no single scope to assign), so there is no add action.
///
/// Recomposed in the project's settings style; backed by
/// [AllMemoriesSearchController].
class SearchMemoryPage extends ConsumerStatefulWidget {
  const SearchMemoryPage({super.key});

  @override
  ConsumerState<SearchMemoryPage> createState() => _SearchMemoryPageState();
}

class _SearchMemoryPageState extends ConsumerState<SearchMemoryPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    ref.read(allMemoriesSearchControllerProvider.notifier).setQuery(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = ref.watch(allMemoriesSearchControllerProvider);
    final assistants = ref.watch(assistantsProvider);
    final nameById = <String, String>{
      for (final a in assistants.asData?.value ?? const <Assistant>[])
        a.id: a.name.trim().isEmpty ? '未命名助手' : a.name,
    };

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
        title: const Text('搜索全部记忆'),
      ),
      body: Column(
        children: [
          _SearchField(
            controller: _searchController,
            onChanged: _onQueryChanged,
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  '加载失败：$e',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return _EmptyState(searching: _query.trim().isNotEmpty);
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = list[i];
                    return MemoryCard(
                      item: item,
                      scopeChip: _ScopeChip(
                        label: item.level == MemoryLevel.global
                            ? '全局'
                            : (nameById[item.ownerId] ?? '助手'),
                        isGlobal: item.level == MemoryLevel.global,
                      ),
                      onTap: () => _edit(item),
                      onDelete: () => _confirmDelete(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(MemoryItem item) async {
    final result = await showMemoryEditor(context, existing: item);
    if (result == null) return;
    await ref.read(allMemoriesSearchControllerProvider.notifier).save(
          item.copyWith(
            content: result.content,
            type: result.type,
            category: result.category,
            importance: result.importance,
          ),
        );
  }

  Future<void> _confirmDelete(MemoryItem item) async {
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
      await ref.read(allMemoriesSearchControllerProvider.notifier).delete(item);
    }
  }
}

/// A scope badge prepended to a search result's chip row: 全局 (tinted) or the
/// owning assistant's name (neutral).
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label, required this.isGlobal});

  final String label;
  final bool isGlobal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isGlobal
        ? const Color(0xFF06B6D4)
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isGlobal
            ? color.withValues(alpha: 0.1)
            : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGlobal ? LucideIcons.globe : LucideIcons.user,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: '搜索全局与助手的全部记忆',
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});

  final bool searching;

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
              searching ? '没有匹配的记忆' : '还没有任何记忆',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              searching ? '换个关键词试试' : '全局与助手的记忆都会在这里被检索到',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
