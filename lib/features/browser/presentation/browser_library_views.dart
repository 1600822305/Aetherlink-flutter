import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/browser/browser_library.dart';

/// 新标签起始页：书签宫格 + 最近访问。
class BrowserStartPage extends StatelessWidget {
  const BrowserStartPage({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final library = BrowserLibrary.instance;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final bookmarks = library.bookmarks;
        final recent = library.history.take(8).toList();
        if (bookmarks.isEmpty && recent.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '在上方输入网址或搜索词即可浏览，登录态会保留。\n'
                '点地址栏右侧的星标收藏页面，收藏和最近访问会显示在这里。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (bookmarks.isNotEmpty) ...[
              _Heading('书签'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final b in bookmarks.take(16))
                    _BookmarkTile(
                      bookmark: b,
                      onTap: () => onOpen(b.url),
                      onRemove: () => library.removeBookmark(b.url),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            if (recent.isNotEmpty) ...[
              _Heading('最近访问'),
              for (final h in recent)
                _HistoryTile(
                  entry: h,
                  onTap: () => onOpen(h.url),
                  onRemove: () => library.removeHistory(h.url),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}

String _hostOf(String url) => Uri.tryParse(url)?.host ?? url;

class _BookmarkTile extends StatelessWidget {
  const _BookmarkTile({
    required this.bookmark,
    required this.onTap,
    required this.onRemove,
  });

  final BrowserBookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final host = _hostOf(bookmark.url);
    final letter = host.isEmpty
        ? '?'
        : host.replaceFirst('www.', '').characters.first.toUpperCase();
    return SizedBox(
      width: 72,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: () => _confirmRemove(context, bookmark.title, onRemove),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  letter,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                bookmark.title.isEmpty ? host : bookmark.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmRemove(
  BuildContext context,
  String title,
  VoidCallback onRemove,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除书签'),
      content: Text('删除「$title」？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (ok == true) onRemove();
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  final BrowserHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(LucideIcons.history, size: 18),
      title: Text(
        entry.title.isEmpty ? entry.url : entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_hostOf(entry.url)} · ${_timeLabel(entry.visitedAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall,
      ),
      trailing: IconButton(
        tooltip: '删除',
        icon: const Icon(LucideIcons.x, size: 16),
        onPressed: onRemove,
      ),
      onTap: onTap,
    );
  }
}

String _timeLabel(DateTime t) {
  final now = DateTime.now();
  final d = now.difference(t);
  if (d.inMinutes < 1) return '刚刚';
  if (d.inHours < 1) return '${d.inMinutes} 分钟前';
  if (d.inDays < 1 && now.day == t.day) {
    return '今天 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
  return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// 资料库抽屉：书签 / 历史 / 下载三个页签。
Future<void> showBrowserLibrarySheet(
  BuildContext context, {
  required ValueChanged<String> onOpen,
  int initialTab = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: DefaultTabController(
        length: 3,
        initialIndex: initialTab,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: '书签'),
                Tab(text: '历史'),
                Tab(text: '下载'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _BookmarksList(onOpen: (url) {
                    Navigator.pop(context);
                    onOpen(url);
                  }),
                  _HistoryList(onOpen: (url) {
                    Navigator.pop(context);
                    onOpen(url);
                  }),
                  const _DownloadsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BookmarksList extends StatelessWidget {
  const _BookmarksList({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final library = BrowserLibrary.instance;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final items = library.bookmarks;
        if (items.isEmpty) return const _EmptyHint('还没有书签');
        return ListView(
          children: [
            for (final b in items)
              ListTile(
                leading: const Icon(LucideIcons.star, size: 18),
                title: Text(
                  b.title.isEmpty ? b.url : b.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  b.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: '删除',
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  onPressed: () => library.removeBookmark(b.url),
                ),
                onTap: () => onOpen(b.url),
              ),
          ],
        );
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final library = BrowserLibrary.instance;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final items = library.history;
        if (items.isEmpty) return const _EmptyHint('没有浏览历史');
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: const Text('清空历史'),
                onPressed: library.clearHistory,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _HistoryTile(
                    entry: items[i],
                    onTap: () => onOpen(items[i].url),
                    onRemove: () => library.removeHistory(items[i].url),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DownloadsList extends StatelessWidget {
  const _DownloadsList();

  @override
  Widget build(BuildContext context) {
    final library = BrowserLibrary.instance;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final items = library.downloads;
        if (items.isEmpty) return const _EmptyHint('没有下载');
        return ListView(
          children: [
            for (final d in items)
              ListTile(
                leading: Icon(switch (d.status) {
                  BrowserDownloadStatus.running => LucideIcons.download,
                  BrowserDownloadStatus.done => LucideIcons.fileCheck,
                  BrowserDownloadStatus.failed => LucideIcons.fileX,
                  BrowserDownloadStatus.cancelled => LucideIcons.ban,
                }, size: 20),
                title: Text(
                  d.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: d.status == BrowserDownloadStatus.running
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: LinearProgressIndicator(value: d.progress),
                      )
                    : Text(
                        switch (d.status) {
                          BrowserDownloadStatus.done =>
                            '${_size(d.received)} · ${d.path ?? ''}',
                          BrowserDownloadStatus.failed =>
                            '失败：${d.error ?? '未知错误'}',
                          BrowserDownloadStatus.cancelled => '已取消',
                          BrowserDownloadStatus.running => '',
                        },
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                trailing: d.status == BrowserDownloadStatus.running
                    ? IconButton(
                        tooltip: '取消',
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => library.cancelDownload(d.id),
                      )
                    : PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'copy' && d.path != null) {
                            await Clipboard.setData(
                              ClipboardData(text: d.path!),
                            );
                          } else if (v == 'remove') {
                            await library.removeDownload(d.id);
                          } else if (v == 'delete') {
                            await library.removeDownload(
                              d.id,
                              deleteFile: true,
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          if (d.path != null && File(d.path!).existsSync())
                            const PopupMenuItem(
                              value: 'copy',
                              child: Text('复制文件路径'),
                            ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('从列表移除'),
                          ),
                          if (d.path != null)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('删除文件'),
                            ),
                        ],
                      ),
              ),
          ],
        );
      },
    );
  }

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
