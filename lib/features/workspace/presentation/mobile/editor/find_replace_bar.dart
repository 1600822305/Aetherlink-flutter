// The find/replace bar shown above the editor body. Owns only its own input
// state (query/replacement text, case & regex toggles); the actual matching
// and text mutation live in the parent editor via the callbacks below.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Search options reported to the parent whenever the query changes.
class FindOptions {
  const FindOptions({required this.caseSensitive, required this.regex});

  final bool caseSensitive;
  final bool regex;
}

class FindReplaceBar extends StatefulWidget {
  const FindReplaceBar({
    super.key,
    required this.matchCount,
    required this.currentIndex,
    required this.showReplace,
    required this.canReplace,
    required this.onQueryChanged,
    required this.onNext,
    required this.onPrev,
    required this.onReplaceOne,
    required this.onReplaceAll,
    required this.onToggleReplace,
    required this.onClose,
  });

  /// Total matches for the current query (0 when none / empty query).
  final int matchCount;

  /// 0-based index of the active match, or -1 when there is none.
  final int currentIndex;

  /// Whether the replacement row is expanded.
  final bool showReplace;

  /// Whether replacing is allowed (editing an editable file). When false the
  /// bar is search-only: no expander, no replacement row.
  final bool canReplace;

  final void Function(String query, FindOptions options) onQueryChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final void Function(String replacement) onReplaceOne;
  final void Function(String replacement) onReplaceAll;
  final VoidCallback onToggleReplace;
  final VoidCallback onClose;

  @override
  State<FindReplaceBar> createState() => _FindReplaceBarState();
}

class _FindReplaceBarState extends State<FindReplaceBar> {
  final _query = TextEditingController();
  final _replacement = TextEditingController();
  bool _caseSensitive = false;
  bool _regex = false;

  @override
  void dispose() {
    _query.dispose();
    _replacement.dispose();
    super.dispose();
  }

  void _emit() => widget.onQueryChanged(
        _query.text,
        FindOptions(caseSensitive: _caseSensitive, regex: _regex),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.matchCount == 0
        ? (_query.text.isEmpty ? '' : '无结果')
        : '${widget.currentIndex + 1}/${widget.matchCount}';
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (widget.canReplace)
                  IconButton(
                    tooltip: widget.showReplace ? '收起替换' : '展开替换',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      widget.showReplace
                          ? LucideIcons.chevronDown
                          : LucideIcons.chevronRight,
                      size: 18,
                    ),
                    onPressed: widget.onToggleReplace,
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(LucideIcons.search, size: 18),
                  ),
                Expanded(
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '查找',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 4),
                Text(label, style: theme.textTheme.bodySmall),
                _ToggleChip(
                  label: 'Aa',
                  tooltip: '区分大小写',
                  active: _caseSensitive,
                  onTap: () {
                    setState(() => _caseSensitive = !_caseSensitive);
                    _emit();
                  },
                ),
                _ToggleChip(
                  label: '.*',
                  tooltip: '正则',
                  active: _regex,
                  onTap: () {
                    setState(() => _regex = !_regex);
                    _emit();
                  },
                ),
                IconButton(
                  tooltip: '上一个',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.chevronUp, size: 18),
                  onPressed: widget.matchCount == 0 ? null : widget.onPrev,
                ),
                IconButton(
                  tooltip: '下一个',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.chevronDown, size: 18),
                  onPressed: widget.matchCount == 0 ? null : widget.onNext,
                ),
                IconButton(
                  tooltip: '关闭',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            if (widget.showReplace && widget.canReplace)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 40, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replacement,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: '替换为',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '替换当前',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.replace, size: 18),
                      onPressed: widget.matchCount == 0
                          ? null
                          : () => widget.onReplaceOne(_replacement.text),
                    ),
                    IconButton(
                      tooltip: '全部替换',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.replaceAll, size: 18),
                      onPressed: widget.matchCount == 0
                          ? null
                          : () => widget.onReplaceAll(_replacement.text),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: active ? theme.colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? theme.colorScheme.onPrimaryContainer : null,
            ),
          ),
        ),
      ),
    );
  }
}
