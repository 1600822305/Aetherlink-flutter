// 文件树的搜索入口：一个 bottom sheet，接 [WorkspaceBackend.searchFiles]
// （文件名 / 内容 / 两者 + 正则），结果按行列出。点结果把该条目 pop 给调用方
// （文件树负责：文件 → 开 tab；目录 → 在树中定位）。
//
// 搜索是防抖触发（输入停 400ms）+ 提交立即触发；每次搜索带代数号，过期结果
// 直接丢弃，避免慢后端（SSH 遍历）把新查询的结果覆盖掉。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/readable_path.dart';

/// 打开搜索 sheet；用户点中某个结果时以该 [WorkspaceEntry] resolve，取消为 null。
Future<WorkspaceEntry?> showWorkspaceSearchSheet(
  BuildContext context, {
  required WorkspaceBackend backend,
  required String rootPath,
}) {
  return showModalBottomSheet<WorkspaceEntry>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) =>
        _SearchSheet(backend: backend, rootPath: rootPath),
  );
}

const int _kMaxResults = 200;
const Duration _kDebounce = Duration(milliseconds: 400);

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
      });
    } on UnsupportedError {
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        _searched = true;
        _error = '当前后端不支持搜索';
        _results = const [];
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        _searched = true;
        _error = '搜索失败 · $e';
        _results = const [];
      });
    }
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _results.length + (capped ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _results.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '结果已达 $_kMaxResults 条上限，请细化关键字',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final entry = _results[i];
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
          onTap: () => Navigator.of(context).pop(entry),
        );
      },
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
