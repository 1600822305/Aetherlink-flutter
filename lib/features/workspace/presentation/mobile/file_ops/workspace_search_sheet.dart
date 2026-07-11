// 文件树的搜索入口：一个 bottom sheet，接 [WorkspaceBackend.searchFiles]
// （文件名 / 内容 / 两者 + 正则）。搜索范围固定为当前工作区根目录（单文件夹
// 项目）。内容搜索时，命中文件会再读一遍正文提取匹配行（行号 + 行预览），
// 按文件分组展示。点结果把 [WorkspaceSearchPick] pop 给调用方（文件树负责：
// 文件 → 开 tab + 可选跳行；目录 → 在树中定位）。
//
// 搜索是防抖触发（输入停 400ms）+ 提交立即触发；每次搜索带代数号，过期结果
// （含逐文件的行预览加载）直接丢弃，避免慢后端（SSH 遍历）把新查询的结果
// 覆盖掉。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_replace_engine.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/readable_path.dart';

/// 搜索 sheet 的选中结果：目标条目 + 可选的跳转行（1-based，点中内容
/// 匹配行时才有）。
class WorkspaceSearchPick {
  const WorkspaceSearchPick(this.entry, {this.line});

  final WorkspaceEntry entry;
  final int? line;
}

/// 打开搜索 sheet；用户点中某个结果时以 [WorkspaceSearchPick] resolve，取消为 null。
Future<WorkspaceSearchPick?> showWorkspaceSearchSheet(
  BuildContext context, {
  required WorkspaceBackend backend,
  required String rootPath,
}) {
  return showModalBottomSheet<WorkspaceSearchPick>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) =>
        _SearchSheet(backend: backend, rootPath: rootPath),
  );
}

const int _kMaxResults = 200;
const Duration _kDebounce = Duration(milliseconds: 400);

// 内容匹配行预览的上限：只给前 [_kMaxPreviewFiles] 个命中文件读正文，
// 每个文件最多展示 [_kMaxLinesPerFile] 行；超过 [_kMaxPreviewBytes] 的大文件
// 不读（只留文件级结果），避免 SAF/SSH 上拖慢整个搜索。
const int _kMaxPreviewFiles = 40;
const int _kMaxLinesPerFile = 5;
const int _kMaxPreviewBytes = 512 * 1024;

/// 一条内容匹配行：1-based 行号 + 去首尾空白的行文本 + 行内高亮区间。
class _LineMatch {
  const _LineMatch(this.line, this.text, this.hlStart, this.hlEnd);

  final int line;
  final String text;
  final int hlStart;
  final int hlEnd;
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.backend, required this.rootPath});

  final WorkspaceBackend backend;
  final String rootPath;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _query = TextEditingController();
  Timer? _debounce;

  WorkspaceSearchType _searchType = WorkspaceSearchType.name;
  bool _useRegex = false;

  // 递增代数号：每次发起搜索 +1，回来的结果与当前代数不符就丢弃。
  int _generation = 0;
  bool _searching = false;
  bool _searched = false;
  String? _error;
  List<WorkspaceEntry> _results = const [];
  // path → 匹配行预览（仅内容/两者模式，逐文件异步填充）。
  Map<String, List<_LineMatch>> _lineMatches = const {};

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, _search);
  }

  void _onOptionsChanged() {
    _debounce?.cancel();
    _search();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    final generation = ++_generation;
    if (query.isEmpty) {
      setState(() {
        _searching = false;
        _searched = false;
        _error = null;
        _results = const [];
      });
      return;
    }
    if (_useRegex) {
      try {
        RegExp(query);
      } on FormatException {
        setState(() {
          _searching = false;
          _searched = true;
          _error = '正则表达式无效';
          _results = const [];
        });
        return;
      }
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.backend.searchFiles(
        widget.rootPath,
        query,
        searchType: _searchType,
        maxResults: _kMaxResults,
        useRegex: _useRegex,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        _searched = true;
        _results = results;
        _lineMatches = const {};
      });
      if (_searchType != WorkspaceSearchType.name) {
        _loadLinePreviews(generation, results, query);
      }
    } on UnsupportedError {
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        _searched = true;
        _error = '当前后端不支持搜索';
        _results = const [];
        _lineMatches = const {};
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        _searched = true;
        _error = '搜索失败 · $e';
        _results = const [];
        _lineMatches = const {};
      });
    }
  }

  // 逐个读命中文件的正文，提取匹配行预览。串行读（SAF/SSH 并发不友好），
  // 每读完一个文件刷一次 UI；代数号对不上就中断。单个文件读失败只跳过，
  // 不影响其它结果。
  Future<void> _loadLinePreviews(
    int generation,
    List<WorkspaceEntry> entries,
    String query,
  ) async {
    var previewed = 0;
    for (final entry in entries) {
      if (generation != _generation || !mounted) return;
      if (entry.isDirectory) continue;
      if (entry.size > _kMaxPreviewBytes) continue;
      if (previewed >= _kMaxPreviewFiles) return;
      previewed++;
      String text;
      try {
        text = await widget.backend.readFile(entry.path);
      } catch (_) {
        continue;
      }
      if (generation != _generation || !mounted) return;
      final matches = findMatches(text, query, regex: _useRegex);
      if (matches.isEmpty) continue;
      final lines = _matchesToLines(text, matches);
      if (lines.isEmpty) continue;
      setState(() {
        _lineMatches = {..._lineMatches, entry.path: lines};
      });
    }
  }

  // 把文本内的匹配偏移映射成去重的行预览（每文件最多 [_kMaxLinesPerFile] 行，
  // 行内只高亮第一个匹配）。
  static List<_LineMatch> _matchesToLines(String text, List<TextMatch> raw) {
    final out = <_LineMatch>[];
    var lineStart = 0;
    var lineNo = 1;
    var i = 0;
    while (i < raw.length && out.length < _kMaxLinesPerFile) {
      final m = raw[i];
      var lineEnd = text.indexOf('\n', lineStart);
      if (lineEnd < 0) lineEnd = text.length;
      if (m.start >= lineEnd + 1) {
        lineStart = lineEnd + 1;
        lineNo++;
        continue;
      }
      final rawLine = text.substring(lineStart, lineEnd);
      final trimmed = rawLine.trimLeft();
      final cut = rawLine.length - trimmed.length;
      final hlStart = (m.start - lineStart - cut).clamp(0, trimmed.length);
      final hlEnd = (m.end - lineStart - cut).clamp(hlStart, trimmed.length);
      out.add(_LineMatch(lineNo, trimmed.trimRight(), hlStart, hlEnd));
      // 同一行的后续匹配全部跳过（一行只列一条）。
      while (i < raw.length && raw[i].start < lineEnd + 1) {
        i++;
      }
      lineStart = lineEnd + 1;
      lineNo++;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _onQueryChanged,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    _search();
                  },
                  decoration: InputDecoration(
                    hintText: '搜索工作区文件…',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final (label, type) in const [
                      ('文件名', WorkspaceSearchType.name),
                      ('内容', WorkspaceSearchType.content),
                      ('两者', WorkspaceSearchType.both),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _searchType == type,
                        visualDensity: VisualDensity.compact,
                        onSelected: (v) {
                          if (!v || _searchType == type) return;
                          setState(() => _searchType = type);
                          _onOptionsChanged();
                        },
                      ),
                    FilterChip(
                      label: const Text('.*'),
                      tooltip: '正则表达式',
                      selected: _useRegex,
                      visualDensity: VisualDensity.compact,
                      onSelected: (v) {
                        setState(() => _useRegex = v);
                        _onOptionsChanged();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Divider(height: 1, color: theme.dividerColor),
              Expanded(child: _body(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    final error = _error;
    if (error != null) return _hint(theme, LucideIcons.circleAlert, error);
    if (!_searched) {
      return _hint(
        theme,
        LucideIcons.search,
        '输入关键字搜索文件名或文件内容',
      );
    }
    if (_results.isEmpty && !_searching) {
      return _hint(theme, LucideIcons.searchX, '没有匹配的文件');
    }
    final capped = _results.length >= _kMaxResults;
    // 把每个文件展开成：文件行 + 它的匹配行（若有），拼成一个扁平列表。
    final rows = <Widget>[];
    for (final entry in _results) {
      rows.add(_fileRow(theme, entry));
      for (final lm in _lineMatches[entry.path] ?? const <_LineMatch>[]) {
        rows.add(_lineRow(theme, entry, lm));
      }
    }
    if (capped) {
      rows.add(
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '结果已达 $_kMaxResults 条上限，请细化关键字',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      itemBuilder: (context, i) => rows[i],
    );
  }

  Widget _fileRow(ThemeData theme, WorkspaceEntry entry) {
    return ListTile(
      dense: true,
      leading: Icon(
        entry.isDirectory ? LucideIcons.folder : LucideIcons.file,
        size: 18,
        color: entry.isDirectory
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        readableWorkspacePath(entry.path),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => Navigator.of(context).pop(WorkspaceSearchPick(entry)),
    );
  }

  // 一条匹配行：缩进在文件行下，行号 + 单行预览（命中段高亮），点击带行号 pop。
  Widget _lineRow(ThemeData theme, WorkspaceEntry entry, _LineMatch lm) {
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    return InkWell(
      onTap: () =>
          Navigator.of(context).pop(WorkspaceSearchPick(entry, line: lm.line)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 4, 16, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '${lm.line}',
                textAlign: TextAlign.right,
                style: mono?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: mono,
                  children: [
                    if (lm.hlStart > 0)
                      TextSpan(text: lm.text.substring(0, lm.hlStart)),
                    TextSpan(
                      text: lm.text.substring(lm.hlStart, lm.hlEnd),
                      style: TextStyle(
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (lm.hlEnd < lm.text.length)
                      TextSpan(text: lm.text.substring(lm.hlEnd)),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hint(ThemeData theme, IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
