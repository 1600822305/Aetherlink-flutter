import 'package:flutter/material.dart';

import '../models/log_entry.dart';
import '../panel.dart';
import 'console_store.dart';

/// The Console [DevToolsPanel]: a searchable, level-filterable view of the
/// captured log ring buffer, styled after the original web `ConsolePanel`
/// (monospace rows, level color + icon, expandable stack traces).
class ConsolePanel extends DevToolsPanel {
  const ConsolePanel();

  @override
  String get title => '控制台';

  @override
  IconData get icon => Icons.terminal;

  @override
  Widget build(BuildContext context) => const _ConsoleView();
}

class _ConsoleView extends StatefulWidget {
  const _ConsoleView();

  @override
  State<_ConsoleView> createState() => _ConsoleViewState();
}

class _ConsoleViewState extends State<_ConsoleView> {
  final ConsoleStore _store = ConsoleStore.instance;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _maybeAutoScroll() {
    if (!_autoScroll || !_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FilterBar(
          store: _store,
          searchCtrl: _searchCtrl,
          autoScroll: _autoScroll,
          onAutoScrollChanged: (v) => setState(() => _autoScroll = v),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: ValueListenableBuilder<List<LogEntry>>(
            valueListenable: _store.entries,
            builder: (context, _, _) {
              return ValueListenableBuilder<ConsoleFilter>(
                valueListenable: _store.filter,
                builder: (context, _, _) {
                  final rows = _store.filtered;
                  _maybeAutoScroll();
                  if (rows.isEmpty) {
                    return const _EmptyHint();
                  }
                  return ListView.builder(
                    controller: _scroll,
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _LogRow(entry: rows[i]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Top bar: a search field plus a row of toggleable level chips and an
/// auto-scroll toggle.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.store,
    required this.searchCtrl,
    required this.autoScroll,
    required this.onAutoScrollChanged,
  });

  final ConsoleStore store;
  final TextEditingController searchCtrl;
  final bool autoScroll;
  final ValueChanged<bool> onAutoScrollChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: searchCtrl,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '搜索日志…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (v) => store.setFilter(
                      store.filter.value.copyWith(search: v),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: '自动滚动',
                isSelected: autoScroll,
                onPressed: () => onAutoScrollChanged(!autoScroll),
                icon: Icon(
                  autoScroll
                      ? Icons.vertical_align_bottom
                      : Icons.vertical_align_center,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<ConsoleFilter>(
            valueListenable: store.filter,
            builder: (context, filter, _) {
              return Wrap(
                spacing: 6,
                children: [
                  for (final level in LogLevel.values)
                    _LevelChip(
                      level: level,
                      selected: filter.levels.contains(level),
                      onTap: () {
                        final next = Set<LogLevel>.from(filter.levels);
                        if (!next.remove(level)) next.add(level);
                        store.setFilter(filter.copyWith(levels: next));
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final LogLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(context, level);
    return FilterChip(
      label: Text(level.label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      side: BorderSide(color: color.withValues(alpha: selected ? 0.5 : 0.2)),
      selectedColor: color.withValues(alpha: 0.12),
      backgroundColor: Colors.transparent,
      onSelected: (_) => onTap(),
    );
  }
}

/// One log line. Tappable to expand a stack trace when present.
class _LogRow extends StatefulWidget {
  const _LogRow({required this.entry});

  final LogEntry entry;

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.entry;
    final color = _levelColor(context, e.level);
    final hasStack = e.stackTrace != null && e.stackTrace!.isNotEmpty;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      height: 1.35,
    );

    return InkWell(
      onTap: hasStack ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: color, width: 3),
            bottom: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_levelIcon(e.level), size: 14, color: color),
                const SizedBox(width: 6),
                Text(_time(e.timestamp), style: mono?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
                if (e.context != null) ...[
                  const SizedBox(width: 6),
                  Text('[${e.context}]', style: mono?.copyWith(color: color)),
                ],
                const SizedBox(width: 8),
                Expanded(child: Text(e.message, style: mono)),
                if (hasStack)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
            if (hasStack && _expanded)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 20),
                child: Text(
                  e.stackTrace!,
                  style: mono?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _time(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.terminal,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            '暂无日志',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

Color _levelColor(BuildContext context, LogLevel level) {
  final scheme = Theme.of(context).colorScheme;
  switch (level) {
    case LogLevel.error:
      return scheme.error;
    case LogLevel.warn:
      return const Color(0xFFE6A23C);
    case LogLevel.info:
      return scheme.primary;
    case LogLevel.debug:
      return scheme.onSurfaceVariant;
    case LogLevel.trace:
      return scheme.onSurfaceVariant.withValues(alpha: 0.7);
  }
}

IconData _levelIcon(LogLevel level) {
  switch (level) {
    case LogLevel.error:
      return Icons.error_outline;
    case LogLevel.warn:
      return Icons.warning_amber_outlined;
    case LogLevel.info:
      return Icons.info_outline;
    case LogLevel.debug:
      return Icons.bug_report_outlined;
    case LogLevel.trace:
      return Icons.notes_outlined;
  }
}
