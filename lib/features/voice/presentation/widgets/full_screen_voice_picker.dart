import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/voice/domain/voice_presets.dart';

/// Full-screen selector overlay matching the Web's FullScreenSelector component.
///
/// Features:
/// - Tab bar for group-based navigation (All + per-group)
/// - Search bar with instant filtering
/// - Grid layout of selectable chips
/// - Current selection highlighting
/// - Optional sub-label for each item
class FullScreenVoicePicker extends StatefulWidget {
  const FullScreenVoicePicker({
    super.key,
    required this.title,
    required this.groups,
    this.selectedKey,
    this.allowEmpty = false,
  });

  final String title;
  final List<SelectorGroup> groups;
  final String? selectedKey;
  final bool allowEmpty;

  /// Shows as a full-screen modal route, returns the selected key or null.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required List<SelectorGroup> groups,
    String? selectedKey,
    bool allowEmpty = false,
  }) {
    return Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        pageBuilder: (ctx, _, __) => FullScreenVoicePicker(
          title: title,
          groups: groups,
          selectedKey: selectedKey,
          allowEmpty: allowEmpty,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  State<FullScreenVoicePicker> createState() => _FullScreenVoicePickerState();
}

class _FullScreenVoicePickerState extends State<FullScreenVoicePicker>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Flatten for "All" tab
  late final List<SelectorItem> _allItems;

  @override
  void initState() {
    super.initState();
    _allItems = widget.groups.expand((g) => g.items).toList();
    // +1 for the "全部" tab
    _tabCtrl = TabController(length: widget.groups.length + 1, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SelectorItem> _filtered(List<SelectorItem> items) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items
        .where((i) =>
            i.label.toLowerCase().contains(q) ||
            i.subLabel.toLowerCase().contains(q) ||
            i.key.toLowerCase().contains(q))
        .toList();
  }

  void _select(String key) {
    Navigator.of(context).pop(key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // -- Header --
          Container(
            padding: EdgeInsets.only(top: padding.top),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Column(
              children: [
                // Title bar
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(LucideIcons.arrowLeft, size: 20),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.allowEmpty)
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(''),
                          child: Text(
                            '清除',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Search bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '搜索...',
                      hintStyle: TextStyle(
                        color: theme.hintColor.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                // Tabs
                TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w400),
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  tabs: [
                    const Tab(text: '全部', height: 36),
                    ...widget.groups.map((g) => Tab(text: g.name, height: 36)),
                  ],
                ),
              ],
            ),
          ),
          // -- Body --
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildGrid(_filtered(_allItems)),
                ...widget.groups
                    .map((g) => _buildGrid(_filtered(g.items))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<SelectorItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.searchX,
                size: 48,
                color: Theme.of(context).hintColor.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('无匹配结果',
                style: TextStyle(
                    color:
                        Theme.of(context).hintColor.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomPad),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 64,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = item.key == widget.selectedKey;
        return _VoiceChip(
          item: item,
          selected: selected,
          onTap: () => _select(item.key),
        );
      },
    );
  }
}

class _VoiceChip extends StatelessWidget {
  const _VoiceChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SelectorItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: selected
          ? primaryColor.withValues(alpha: 0.12)
          : theme.colorScheme.onSurface.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: primaryColor, width: 1.5)
                : Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  if (selected)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(LucideIcons.check,
                          size: 14, color: primaryColor),
                    ),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? primaryColor
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (item.subLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.subLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
