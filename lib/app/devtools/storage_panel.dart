import 'package:aetherlink_devtools/aetherlink_devtools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';

/// The Storage [DevToolsPanel]: a Chrome-Application-panel-style view of the
/// app's persisted state — SharedPreferences (view / edit / delete) and the
/// Drift/SQLite tables (read-only browse), per devtools-design §5.4.
///
/// A bridge panel in `app/` (the composition root) so the dependency-free
/// `aetherlink_devtools` package needn't know about Drift / SharedPreferences;
/// it reaches the live DB via `appDatabaseProvider`. Values are shown verbatim
/// (no redaction — a local, open-source dev tool, like browser devtools).
class StoragePanel extends DevToolsPanel {
  const StoragePanel();

  @override
  String get title => '存储';

  @override
  IconData get icon => Icons.sd_storage_outlined;

  @override
  Widget build(BuildContext context) => const _StorageView();
}

class _StorageView extends ConsumerStatefulWidget {
  const _StorageView();

  @override
  ConsumerState<_StorageView> createState() => _StorageViewState();
}

class _StorageViewState extends ConsumerState<_StorageView> {
  late Future<_StorageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StorageData> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final prefEntries = <_PrefEntry>[
      for (final k in (prefs.getKeys().toList()..sort()))
        _PrefEntry(k, prefs.get(k)),
    ];

    final db = ref.read(appDatabaseProvider);
    final tables = <_TableEntry>[];
    for (final t in db.allTables) {
      final name = t.actualTableName;
      var count = -1;
      try {
        final row = await db
            .customSelect('SELECT COUNT(*) AS c FROM "$name"')
            .getSingle();
        count = row.read<int>('c');
      } catch (_) {}
      tables.add(_TableEntry(name, count));
    }
    tables.sort((a, b) => a.name.compareTo(b.name));
    return _StorageData(prefEntries, tables);
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StorageData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _Error(message: '读取存储失败：${snap.error}', onRetry: _refresh);
        }
        final data = snap.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
          children: [
            _SectionHeader(
              icon: Icons.tune,
              title: 'SharedPreferences',
              trailing: '${data.prefs.length}',
            ),
            if (data.prefs.isEmpty)
              const _EmptyLine('（无键值）')
            else
              for (final e in data.prefs)
                _PrefTile(entry: e, onChanged: _refresh),
            const SizedBox(height: 14),
            _SectionHeader(
              icon: Icons.table_chart_outlined,
              title: 'Drift / SQLite 表',
              trailing: '${data.tables.length}',
            ),
            for (final t in data.tables) _TableTile(table: t),
          ],
        );
      },
    );
  }
}

/// One SharedPreferences entry: key + typed value, editable (string) / deletable.
class _PrefTile extends StatelessWidget {
  const _PrefTile({required this.entry, required this.onChanged});

  final _PrefEntry entry;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Chip(entry.typeLabel, theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SelectableText(
                        entry.key,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  entry.displayValue,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (entry.value is String)
            IconButton(
              tooltip: '编辑',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _edit(context),
            ),
          IconButton(
            tooltip: '删除',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _delete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: entry.value as String);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑 ${entry.key}'),
        content: TextField(
          controller: ctrl,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(entry.key, result);
    onChanged();
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该键？'),
        content: Text(entry.key),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(entry.key);
    onChanged();
  }
}

/// One Drift table: name + row count, expandable to browse the first rows.
class _TableTile extends ConsumerStatefulWidget {
  const _TableTile({required this.table});

  final _TableEntry table;

  @override
  ConsumerState<_TableTile> createState() => _TableTileState();
}

class _TableTileState extends ConsumerState<_TableTile> {
  static const int _limit = 100;
  bool _expanded = false;
  Future<List<Map<String, dynamic>>>? _rows;

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      _rows ??= _loadRows();
    });
  }

  Future<List<Map<String, dynamic>>> _loadRows() async {
    final db = ref.read(appDatabaseProvider);
    final res = await db
        .customSelect('SELECT * FROM "${widget.table.name}" LIMIT $_limit')
        .get();
    return res.map((r) => r.data).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: widget.table.count == 0 ? null : _toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: widget.table.count == 0
                        ? theme.disabledColor
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.table.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _Chip(
                    widget.table.count < 0 ? '?' : '${widget.table.count}',
                    theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _rows,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final rows = snap.data ?? const [];
                if (rows.isEmpty) return const _EmptyLine('（空表）');
                return _TableRows(rows: rows, limit: _limit);
              },
            ),
        ],
      ),
    );
  }
}

/// A horizontally + vertically scrollable preview of table rows.
class _TableRows extends StatelessWidget {
  const _TableRows({required this.rows, required this.limit});

  final List<Map<String, dynamic>> rows;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = rows.first.keys.toList(growable: false);
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 11.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 32,
                  dataRowMinHeight: 28,
                  dataRowMaxHeight: 44,
                  columnSpacing: 18,
                  horizontalMargin: 10,
                  columns: [
                    for (final c in columns)
                      DataColumn(
                        label: Text(
                          c,
                          style: mono?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                  rows: [
                    for (final r in rows)
                      DataRow(
                        cells: [
                          for (final c in columns)
                            DataCell(
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 240),
                                child: Text(
                                  '${r[c] ?? 'null'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: mono,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (rows.length >= limit)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '仅显示前 $limit 行',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          _Chip(trailing, theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _PrefEntry {
  _PrefEntry(this.key, this.value);

  final String key;
  final Object? value;

  String get typeLabel {
    final v = value;
    if (v is String) return 'String';
    if (v is int) return 'int';
    if (v is double) return 'double';
    if (v is bool) return 'bool';
    if (v is List) return 'List';
    return v.runtimeType.toString();
  }

  String get displayValue {
    final v = value;
    if (v is List) return v.join(', ');
    return '$v';
  }
}

class _TableEntry {
  _TableEntry(this.name, this.count);

  final String name;
  final int count;
}

class _StorageData {
  _StorageData(this.prefs, this.tables);

  final List<_PrefEntry> prefs;
  final List<_TableEntry> tables;
}
