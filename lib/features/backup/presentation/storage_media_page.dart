import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/backup/application/storage_media_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_media.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';
import 'package:aetherlink_flutter/features/backup/presentation/storage_widgets.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_block_preview.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/image_preview_page.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/media_blocks.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

class StorageMediaPage extends ConsumerStatefulWidget {
  const StorageMediaPage({required this.isImageView,
    this.initialFilter = StorageMediaFilter.all, super.key});
  final bool isImageView;
  final StorageMediaFilter initialFilter;

  @override
  ConsumerState<StorageMediaPage> createState() => _StorageMediaPageState();
}

class _StorageMediaPageState extends ConsumerState<StorageMediaPage> {
  final _selected = <String>{};
  var _filter = StorageMediaFilter.all;
  var _sort = StorageMediaSort.newest;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    Future.microtask(() {
      if (mounted) ref.read(storageMediaControllerProvider.notifier).refresh();
    });
  }

  void _toggle(StorageMedia item) {
    if (!item.canDelete) return;
    setState(() {
      if (!_selected.remove(item.id)) _selected.add(item.id);
    });
  }

  void _back() {
    if (ref.read(storageMediaControllerProvider).isBusy) return;
    if (_selected.isNotEmpty) {
      setState(_selected.clear);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _delete(Set<String> ids) async {
    if (ids.isEmpty) return;
    final snapshot = Set<String>.of(ids);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除所选文件', style: TextStyle(fontSize: 15)),
        content: Text('移除这 ${snapshot.length} 项未使用文件吗？'
          '执行时会再次核对引用，仍在使用的项目将保留。',
          style: const TextStyle(fontSize: 12.5, height: 1.3)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(fontSize: 13))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除', style: TextStyle(fontSize: 13))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await ref.read(storageMediaControllerProvider.notifier).deleteUnused(snapshot);
      if (!mounted) return;
      setState(_selected.clear);
      AppToast.success(context, '已删除 ${result.deleted} 项；'
        '${result.kept} 项正在使用或无法删除，已保留');
    } catch (error) {
      if (mounted) {
        setState(_selected.clear);
        AppToast.error(context, '删除失败：$error');
      }
    }
  }

  void _topic(StorageMedia item) {
    try {
      ref.read(storageMediaControllerProvider.notifier).selectTopic(item);
      context.go(AppRouter.chatPath);
    } catch (error) {
      AppToast.error(context, '$error');
    }
  }

  Future<void> _open(StorageMedia item) async {
    if (_selected.isNotEmpty && item.canDelete) {
      _toggle(item);
      return;
    }
    try {
      if (item.isImage) {
        final provider = await _imageProvider(item,
          ref.read(storageMediaControllerProvider.notifier).blockPayload);
        if (mounted) showImagePreview(context, provider: provider, heroTag: item.id);
      } else if (item.isChat && item.mimeType.startsWith('video/') &&
          (item.isInline || !p.isAbsolute(item.source))) {
        final raw = await ref.read(storageMediaControllerProvider.notifier).blockPayload(item.id);
        final block = await _messageBlock(raw);
        if (!mounted) return;
        if (block is! VideoBlock) throw StateError('视频块格式不完整');
        await openStoragePage(context, Scaffold(
          appBar: ModelSettingsAppBar(title: item.name),
          body: Center(child: VideoBlockView(block: block)),
        ));
      } else if (!item.isInline && p.isAbsolute(item.source)) {
        await ref.read(shareApiProvider).shareFiles([item.source]);
      } else if (!item.isInline && RegExp(r'^https?://').hasMatch(item.source)) {
        if (!await launchUrl(Uri.parse(item.source), mode: LaunchMode.externalApplication)) {
          throw StateError('系统无法打开此链接');
        }
      } else if (item.isChat) {
        final raw = await ref.read(storageMediaControllerProvider.notifier).blockPayload(item.id);
        final block = await _messageBlock(raw);
        if (!mounted) return;
        if (block is FileBlock) {
          await showFileBlockPreview(context, block);
        } else if (block is VideoBlock) {
          await openStoragePage(context, Scaffold(
            appBar: ModelSettingsAppBar(title: item.name),
            body: Center(child: VideoBlockView(block: block)),
          ));
        } else {
          throw StateError('此媒体暂不能预览');
        }
      } else {
        await ref.read(shareApiProvider).shareFiles([item.source]);
      }
    } catch (error) {
      if (mounted) AppToast.error(context, '无法打开：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storageMediaControllerProvider);
    final controller = ref.read(storageMediaControllerProvider.notifier);
    final items = visibleStorageMedia(state.items,
      isImageView: widget.isImageView, filter: _filter, sort: _sort);
    final deletable = items.where((item) => item.canDelete).map((item) => item.id).toSet();
    final selected = _selected.intersection(deletable);
    final enabled = !state.isBusy && !state.isLoading;
    final allSelected = deletable.isNotEmpty && selected.length == deletable.length;
    return PopScope(
      canPop: !state.isBusy && _selected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.isBusy && _selected.isNotEmpty) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: ModelSettingsAppBar(title: widget.isImageView ? '图片' : '文件', onBack: _back,
          actions: [IconButton(icon: const Icon(LucideIcons.refreshCw, size: 16),
            onPressed: !enabled ? null : () { setState(_selected.clear); controller.refresh(); })]),
        body: CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StorageCard(child: Padding(padding: const EdgeInsets.all(14), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StorageUsageText(formatStorageBytes(items.fold<int>(0, (sum, item) => sum + item.bytes))),
                    const StorageNotice('正在使用的文件不会被清理。这里是管理视图，不重复计入总占用；'
                      '聊天媒体按内容大小展示，远程文件未提供大小时显示 0 B。'),
                  ],
                ))),
                if (widget.isImageView) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: [
                    for (final filter in StorageMediaFilter.values)
                      ChoiceChip(label: Text(switch (filter) {
                        StorageMediaFilter.all => '全部', StorageMediaFilter.chat => '聊天图片',
                        StorageMediaFilter.tools => '工具截图', StorageMediaFilter.avatars => '头像',
                      }, style: const TextStyle(fontSize: 12)),
                        selected: filter == _filter,
                        onSelected: !enabled ? null : (_) => setState(() { _filter = filter; _selected.clear(); })),
                  ]),
                  Wrap(spacing: 6, children: [
                    for (final sort in StorageMediaSort.values)
                      ChoiceChip(label: Text(switch (sort) {
                        StorageMediaSort.newest => '最新', StorageMediaSort.oldest => '最旧',
                        StorageMediaSort.largest => '最大', StorageMediaSort.smallest => '最小',
                      }, style: const TextStyle(fontSize: 12)),
                        selected: sort == _sort,
                        onSelected: !enabled ? null : (_) => setState(() { _sort = sort; })),
                  ]),
                ],
                Wrap(spacing: 4, children: [
                  TextButton(onPressed: !enabled || deletable.isEmpty ? null : () {
                    setState(() { _selected..clear()..addAll(deletable); });
                    _delete(deletable);
                  }, child: const Text('清理未使用', style: TextStyle(fontSize: 12))),
                  TextButton(onPressed: !enabled || deletable.isEmpty ? null : () => setState(() {
                    _selected.clear(); if (!allSelected) _selected.addAll(deletable);
                  }), child: Text(allSelected ? '取消选择' : '全选', style: const TextStyle(fontSize: 12))),
                  TextButton(onPressed: !enabled || selected.isEmpty ? null : () => _delete(selected),
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    child: const Text('删除', style: TextStyle(fontSize: 12))),
                ]),
                Text(selected.isEmpty ? '共 ${items.length} 项' : '已选 ${selected.length} 项',
                  style: const TextStyle(fontSize: 12)),
                if (state.isLoading || state.isBusy) const LinearProgressIndicator(),
                if (state.error != null) ...[
                  StorageNotice('加载未完成：${state.error}'),
                  TextButton(onPressed: controller.refresh, child: const Text('重试')),
                ],
                if (enabled && state.error == null && items.isEmpty) const StorageNotice('当前没有符合条件的项目'),
              ],
            )),
          ),
          if (widget.isImageView)
            SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120, crossAxisSpacing: 8, mainAxisSpacing: 8),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = items[index];
                  return GestureDetector(
                    onTap: !enabled ? null : () => _open(item),
                    onLongPress: !enabled || !item.canDelete ? null : () => _toggle(item),
                    child: DecoratedBox(decoration: BoxDecoration(
                      border: Border.all(color: selected.contains(item.id)
                        ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8)),
                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Stack(
                        fit: StackFit.expand, children: [
                          _MediaThumbnail(key: ValueKey('${item.id}:${item.modifiedAt}'),
                            item: item, loadPayload: controller.blockPayload),
                          Positioned(top: 0, right: 0, child: item.isInUse
                            ? Container(color: Colors.black54, padding: const EdgeInsets.all(4),
                                child: const Text('使用中', style: TextStyle(fontSize: 10, color: Colors.white)))
                            : Checkbox(value: selected.contains(item.id),
                                onChanged: !enabled ? null : (_) => _toggle(item))),
                          Positioned(bottom: 0, left: 0, right: 0,
                            child: ColoredBox(color: Colors.black54, child: Row(children: [
                              Expanded(child: Padding(padding: const EdgeInsets.all(4),
                                child: Text(item.status, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: Colors.white)))),
                              if (item.topicId != null) IconButton(
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28), padding: EdgeInsets.zero,
                                tooltip: '前往${item.topicTitle}', icon: const Icon(LucideIcons.messagesSquare, size: 14, color: Colors.white),
                                onPressed: !enabled ? null : () => _topic(item)),
                            ]))),
                        ],
                      )),
                    ),
                  );
                }, childCount: items.length),
              ))
          else
            SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                final item = items[index];
                return ListTile(
                  dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: item.isInUse ? const Text('使用中', style: TextStyle(fontSize: 10))
                    : Checkbox(value: selected.contains(item.id), onChanged: !enabled ? null : (_) => _toggle(item)),
                  title: Row(children: [
                    const Icon(LucideIcons.file, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.name, style: const TextStyle(fontSize: 14))),
                  ]),
                  subtitle: Text('${formatStorageBytes(item.bytes)} · ${_date(item.modifiedAt)}\n${item.status}',
                    style: const TextStyle(fontSize: 12, height: 1.3)),
                  trailing: item.topicId == null ? null : IconButton(tooltip: '前往话题',
                    icon: const Icon(LucideIcons.messagesSquare, size: 16),
                    onPressed: !enabled ? null : () => _topic(item)),
                  onTap: !enabled ? null : () => _open(item),
                  onLongPress: !enabled || !item.canDelete ? null : () => _toggle(item),
                );
              }, childCount: items.length))),
        ]),
      ),
    );
  }
}

String _date(DateTime value) {
  final date = value.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${pad(date.month)}-${pad(date.day)} ${pad(date.hour)}:${pad(date.minute)}';
}

Future<ImageProvider> _imageProvider(StorageMedia item,
    Future<String> Function(String) loadPayload) async {
  if (item.isInline) {
    final raw = await loadPayload(item.id);
    final bytes = await Isolate.run(() {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final file = data['file'] as Map<String, dynamic>?;
      final source = (data['base64Data'] as String?)?.isNotEmpty == true
          ? data['base64Data'] as String
          : (file?['base64Data'] as String?)?.isNotEmpty == true
              ? file!['base64Data'] as String
              : data['url'] as String? ?? '';
      final encoded = source.startsWith('data:') ? source.substring(source.indexOf(',') + 1) : source;
      return base64Decode(encoded.replaceAll(RegExp(r'\s'), ''));
    });
    return MemoryImage(bytes);
  }
  if (RegExp(r'^https?://').hasMatch(item.source)) return CachedNetworkImageProvider(item.source);
  return FileImage(File(item.source));
}

Future<MessageBlock> _messageBlock(String raw) async {
  final data = await Isolate.run(() => jsonDecode(raw) as Map<String, dynamic>);
  return MessageBlock.fromJson(data);
}

class _MediaThumbnail extends StatefulWidget {
  const _MediaThumbnail({required this.item, required this.loadPayload, super.key});
  final StorageMedia item;
  final Future<String> Function(String) loadPayload;
  @override
  State<_MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<_MediaThumbnail> {
  late Future<ImageProvider> _provider = _imageProvider(widget.item, widget.loadPayload);

  @override
  void didUpdateWidget(_MediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.source != widget.item.source ||
        oldWidget.item.modifiedAt != widget.item.modifiedAt) {
      _provider = _imageProvider(widget.item, widget.loadPayload);
    }
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<ImageProvider>(
    future: _provider,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const Icon(LucideIcons.imageOff, size: 18);
      final provider = snapshot.data;
      if (provider == null) return const Center(child: SizedBox(width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2)));
      if (provider is MemoryImage) {
        return Image.memory(provider.bytes, cacheWidth: 240, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(LucideIcons.imageOff, size: 18));
      }
      if (provider is FileImage) {
        return Image.file(provider.file, cacheWidth: 240, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(LucideIcons.imageOff, size: 18));
      }
      return Image(image: ResizeImage.resizeIfNeeded(240, null, provider), fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(LucideIcons.imageOff, size: 18));
    },
  );
}
