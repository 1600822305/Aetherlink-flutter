import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../panel.dart';
import 'network_entry.dart';
import 'network_store.dart';

/// The Network [DevToolsPanel]: a searchable, filterable list of captured Dio
/// requests with a detail drawer (Headers / Payload / Response / Timing), styled
/// after the original web `NetworkPanel` (method/status color chips, monospace
/// bodies) and aware of streaming/SSE responses that fill in chunk by chunk.
class NetworkPanel extends DevToolsPanel {
  const NetworkPanel();

  @override
  String get title => '网络';

  @override
  IconData get icon => Icons.language;

  @override
  Widget build(BuildContext context) => const _NetworkView();

  @override
  void onClear() => NetworkStore.instance.clear();

  @override
  String exportAsText() =>
      NetworkStore.instance.filtered.map((e) => e.toDetailText()).join('\n\n');
}

const List<String> _methods = <String>[
  'GET',
  'POST',
  'PUT',
  'DELETE',
  'PATCH',
];

class _NetworkView extends StatefulWidget {
  const _NetworkView();

  @override
  State<_NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends State<_NetworkView> {
  final NetworkStore _store = NetworkStore.instance;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FilterBar(store: _store, searchCtrl: _searchCtrl),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: ValueListenableBuilder<List<NetworkEntry>>(
            valueListenable: _store.entries,
            builder: (context, _, _) {
              return ValueListenableBuilder<NetworkFilter>(
                valueListenable: _store.filter,
                builder: (context, _, _) {
                  final rows = _store.filtered;
                  if (rows.isEmpty) return const _EmptyHint();
                  // Longest latency among visible rows → the waterfall bars are
                  // drawn relative to it.
                  var maxMs = 1;
                  for (final e in rows) {
                    final ms = e.duration?.inMilliseconds ?? 0;
                    if (ms > maxMs) maxMs = ms;
                  }
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _RequestRow(
                      entry: rows[i],
                      maxDurationMs: maxMs,
                      onTap: () => _openDetails(rows[i].id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openDetails(int id) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (_) => _DetailsSheet(store: _store, id: id),
    );
  }
}

const Map<String, int> _sizeThresholds = <String, int>{
  '全部': 0,
  '>1KB': 1024,
  '>100KB': 102400,
  '>1MB': 1048576,
};

/// Top bar: a search field + errors/advanced toggles, method chips, and a
/// collapsible advanced row (status-code class / 仅流式 / 最小大小).
class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.store, required this.searchCtrl});

  final NetworkStore store;
  final TextEditingController searchCtrl;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = widget.store;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Column(
        children: [
          ValueListenableBuilder<NetworkFilter>(
            valueListenable: store.filter,
            builder: (context, filter, _) => Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: TextField(
                      controller: widget.searchCtrl,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '搜索 URL / 方法 / 状态码…',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) =>
                          store.setFilter(filter.copyWith(search: v)),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '仅显示错误',
                  isSelected: filter.onlyErrors,
                  onPressed: () => store.setFilter(
                    filter.copyWith(onlyErrors: !filter.onlyErrors),
                  ),
                  icon: Icon(
                    filter.onlyErrors ? Icons.error : Icons.error_outline,
                    size: 20,
                    color: filter.onlyErrors ? theme.colorScheme.error : null,
                  ),
                ),
                IconButton(
                  tooltip: '更多筛选',
                  isSelected: _showAdvanced,
                  onPressed: () =>
                      setState(() => _showAdvanced = !_showAdvanced),
                  icon: const Icon(Icons.tune, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ValueListenableBuilder<NetworkFilter>(
            valueListenable: store.filter,
            builder: (context, filter, _) {
              return Wrap(
                spacing: 6,
                children: [
                  for (final m in _methods)
                    _MethodChip(
                      method: m,
                      // Empty set means "all"; a chip is shown selected when
                      // either all are on or it's explicitly included.
                      selected:
                          filter.methods.isEmpty || filter.methods.contains(m),
                      onTap: () {
                        final next = filter.methods.isEmpty
                            ? Set<String>.from(_methods)
                            : Set<String>.from(filter.methods);
                        if (!next.remove(m)) next.add(m);
                        store.setFilter(filter.copyWith(methods: next));
                      },
                    ),
                ],
              );
            },
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 8),
            ValueListenableBuilder<NetworkFilter>(
              valueListenable: store.filter,
              builder: (context, filter, _) => _advancedRow(context, filter),
            ),
          ],
        ],
      ),
    );
  }

  Widget _advancedRow(BuildContext context, NetworkFilter filter) {
    final store = widget.store;
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final cls in const [2, 3, 4, 5])
          FilterChip(
            label: Text('${cls}xx'),
            selected: filter.statusClasses.contains(cls),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            onSelected: (_) {
              final next = Set<int>.from(filter.statusClasses);
              if (!next.remove(cls)) next.add(cls);
              store.setFilter(filter.copyWith(statusClasses: next));
            },
          ),
        FilterChip(
          label: const Text('仅流式'),
          selected: filter.onlyStream,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          onSelected: (_) =>
              store.setFilter(filter.copyWith(onlyStream: !filter.onlyStream)),
        ),
        DropdownButton<int>(
          value: filter.minSize,
          isDense: true,
          underline: const SizedBox.shrink(),
          style: theme.textTheme.bodySmall,
          items: [
            for (final e in _sizeThresholds.entries)
              DropdownMenuItem<int>(value: e.value, child: Text(e.key)),
          ],
          onChanged: (v) =>
              store.setFilter(filter.copyWith(minSize: v ?? 0)),
        ),
      ],
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final String method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _methodColor(method);
    return FilterChip(
      label: Text(method),
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

/// One request line: method chip + status + short URL + duration/size, with a
/// waterfall bar underneath sized relative to the slowest visible request.
class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.entry,
    required this.maxDurationMs,
    required this.onTap,
  });

  final NetworkEntry entry;
  final int maxDurationMs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(context, entry.status);
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      height: 1.3,
    );
    final d = entry.duration;
    final size = entry.responseSize;
    final fraction = d == null
        ? null
        : (d.inMilliseconds / maxDurationMs).clamp(0.02, 1.0);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: statusColor, width: 3),
            bottom: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Tag(text: entry.method, color: _methodColor(entry.method)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    entry.statusCode?.toString() ?? entry.status.label,
                    style: mono?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.shortUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono,
                  ),
                ),
                if (entry.isStream)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.stream,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  d == null ? '—' : formatDuration(d),
                  style: mono?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (size != null && size > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    formatSize(size),
                    style: mono?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            // Waterfall bar: width ∝ latency relative to the slowest visible row.
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Row(
                children: [
                  Expanded(
                    flex: ((fraction ?? 0) * 1000).round(),
                    child: Container(height: 3, color: statusColor),
                  ),
                  Expanded(
                    flex: 1000 - ((fraction ?? 0) * 1000).round(),
                    child: const SizedBox(height: 3),
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

/// The detail drawer. Listens to the store so a streaming response fills in live
/// while open. Sections: General / Request Headers / Payload / Response Headers /
/// Response / Timing.
class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({required this.store, required this.id});

  final NetworkStore store;
  final int id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<List<NetworkEntry>>(
      valueListenable: store.entries,
      builder: (context, _, _) {
        final e = store.byId(id);
        if (e == null) {
          return const SizedBox(
            height: 120,
            child: Center(child: Text('该请求已被清除')),
          );
        }
        final statusColor = _statusColor(context, e.status);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  _Tag(text: e.method, color: _methodColor(e.method)),
                  const SizedBox(width: 8),
                  Text(
                    e.statusCode?.toString() ?? e.status.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '复制为 cURL',
                    onPressed: () => _copy(context, e.toCurl(), label: '已复制 cURL'),
                    icon: const Icon(Icons.terminal, size: 20),
                  ),
                  IconButton(
                    tooltip: '复制响应体',
                    onPressed: (e.responseData == null || e.responseData!.isEmpty)
                        ? null
                        : () => _copy(context, e.responseData!, label: '已复制响应体'),
                    icon: const Icon(Icons.download_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: '复制全部',
                    onPressed: () => _copy(context, e.toDetailText()),
                    icon: const Icon(Icons.copy_outlined, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _kv(context, 'URL', e.url, copyable: true),
                  _kv(context, '耗时', e.duration == null
                      ? '进行中…'
                      : formatDuration(e.duration!)),
                  if (e.responseSize != null)
                    _kv(context, '响应大小', formatSize(e.responseSize!)),
                  if (e.requestSize != null)
                    _kv(context, '请求大小', formatSize(e.requestSize!)),
                  const SizedBox(height: 8),
                  _Section(
                    title: '请求头',
                    body: _mapText(e.requestHeaders),
                  ),
                  if (e.requestPayload != null &&
                      e.requestPayload!.isNotEmpty)
                    _Section(title: '请求体', body: e.requestPayload!),
                  _Section(
                    title: '响应头',
                    body: _mapText(e.responseHeaders),
                  ),
                  _Section(
                    title: e.isStream
                        ? '响应体（流式，${formatSize(e.responseSize ?? 0)}）'
                        : '响应体',
                    body: (e.responseData == null || e.responseData!.isEmpty)
                        ? (e.status == NetworkStatus.pending
                            ? '等待响应…'
                            : '(空)')
                        : e.responseData!,
                    streaming: e.isStream && e.status == NetworkStatus.pending,
                  ),
                  if (e.error != null)
                    _Section(
                      title: '错误',
                      body: '${e.error}\n${e.errorStack ?? ''}'.trim(),
                      tint: theme.colorScheme.error,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(
    BuildContext context,
    String k,
    String v, {
    bool copyable = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              k,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (copyable)
            InkWell(
              onTap: () => _copy(context, v),
              child: Icon(
                Icons.copy_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  static String _mapText(Map<String, String> m) {
    if (m.isEmpty) return '(none)';
    return m.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  Future<void> _copy(
    BuildContext context,
    String text, {
    String label = '已复制',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(label)));
    }
  }
}

/// A labeled, collapsible monospace block used by the detail drawer.
class _Section extends StatefulWidget {
  const _Section({
    required this.title,
    required this.body,
    this.streaming = false,
    this.tint,
  });

  final String title;
  final String body;
  final bool streaming;
  final Color? tint;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  /// Each body scrolls within this height instead of expanding the whole sheet,
  /// so a huge JSON payload/response no longer forces a long page-scroll to
  /// reach the sections below it.
  static const double _maxBodyHeight = 260;

  bool _expanded = true;
  final ScrollController _bodyScroll = ScrollController();

  @override
  void dispose() {
    _bodyScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Section old) {
    super.didUpdateWidget(old);
    // Follow the tail while a stream is still appending (like a live log).
    if (widget.streaming && widget.body != old.body) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_bodyScroll.hasClients) {
          _bodyScroll.jumpTo(_bodyScroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: widget.tint,
                  ),
                ),
                if (widget.streaming) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _maxBodyHeight),
              child: Scrollbar(
                controller: _bodyScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _bodyScroll,
                  primary: false,
                  child: SelectableText(
                    widget.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.4,
                      color: widget.tint,
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          fontFamily: 'monospace',
        ),
      ),
    );
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
            Icons.language,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            '暂无网络请求',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(BuildContext context, NetworkStatus status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case NetworkStatus.pending:
      return const Color(0xFFE6A23C); // orange
    case NetworkStatus.success:
      return const Color(0xFF67C23A); // green
    case NetworkStatus.error:
      return scheme.error;
    case NetworkStatus.cancelled:
      return scheme.onSurfaceVariant;
  }
}

Color _methodColor(String method) {
  switch (method.toUpperCase()) {
    case 'GET':
      return const Color(0xFF2196F3); // blue
    case 'POST':
      return const Color(0xFF4CAF50); // green
    case 'PUT':
      return const Color(0xFFFF9800); // orange
    case 'DELETE':
      return const Color(0xFFF44336); // red
    case 'PATCH':
      return const Color(0xFF9C27B0); // purple
    default:
      return const Color(0xFF607D8B); // blue grey
  }
}
