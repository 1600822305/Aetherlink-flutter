import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/mobile/settings_search_index.dart';

/// Independent settings search page. Shows a search bar at the top and a
/// filtered result list. Each result navigates to the target settings route.
class SettingsSearchPage extends StatefulWidget {
  const SettingsSearchPage({super.key});

  @override
  State<SettingsSearchPage> createState() => _SettingsSearchPageState();
}

class _SettingsSearchPageState extends State<SettingsSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<SettingsSearchEntry> _results = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    // Auto-focus the search field on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() {
      _results = kSettingsSearchIndex
          .where((e) => e.matches(query))
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
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
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: _SearchField(controller: _controller, focusNode: _focusNode),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18),
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: () => _controller.clear(),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _results.isEmpty
          ? _EmptyState(hasQuery: _controller.text.trim().isNotEmpty)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
              itemBuilder: (context, index) {
                final entry = _results[index];
                return _SearchResultTile(
                  entry: entry,
                  onTap: () => context.push(entry.route),
                );
              },
            ),
    );
  }
}

/// The search text field embedded in the AppBar title slot.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontSize: 16,
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: '搜索设置...',
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }
}

/// A single search result row — icon + title/group + chevron.
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.entry, required this.onTap});

  final SettingsSearchEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                entry.icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.group.isNotEmpty
                        ? '${entry.group} · ${entry.description}'
                        : entry.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when no results: a prompt to type, or "no results found".
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});

  final bool hasQuery;

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
              hasQuery ? LucideIcons.searchX : LucideIcons.search,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery ? '没有找到相关设置' : '输入关键词搜索设置',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
