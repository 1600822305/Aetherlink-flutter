import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/storage_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';
import 'package:aetherlink_flutter/features/backup/presentation/storage_widgets.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

class TopicStoragePage extends ConsumerStatefulWidget {
  const TopicStoragePage({super.key});

  @override
  ConsumerState<TopicStoragePage> createState() => _TopicStoragePageState();
}

class _TopicStoragePageState extends ConsumerState<TopicStoragePage> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storageControllerProvider);
    final controller = ref.read(storageControllerProvider.notifier);
    final enabled = !state.isBusy && !state.isLoading;
    final topics = state.topics;
    final visibleIds = topics.map((topic) => topic.id).toSet();
    final selected = _selected.intersection(visibleIds);
    final theme = Theme.of(context);
    final header = Padding(
      padding: const EdgeInsets.all(16),
      child: StorageCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StorageUsageText(
                          formatStorageBytes(
                            state.report?.categories[StorageCategory.chat]?.bytes ??
                                0,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: !enabled || topics.isEmpty
                            ? null
                            : () => setState(() {
                                _selected.clear();
                                if (selected.length != topics.length) {
                                  _selected.addAll(visibleIds);
                                }
                              }),
                        child: Text(
                          selected.length == topics.length && topics.isNotEmpty
                              ? '取消全选'
                              : '全选话题',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const StorageNotice(
                    '下面按消息块 JSON 字节数排列话题，包含图片和视频数据，'
                    '不含数据库索引等开销。消息数不包含内部根节点。'
                    '删除记录后需压缩数据库，才能归还空闲空间。',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            StorageRow(
              icon: LucideIcons.database,
              label: '压缩数据库',
              onTap: !enabled
                  ? null
                  : () => confirmStorageAction(
                      context,
                      title: '压缩数据库',
                      message: '将重新整理数据库以回收已删除内容占用的空间。'
                          '需要额外磁盘空间，期间请勿退出应用。',
                      action: controller.vacuum,
                      isDestructive: false,
                    ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            StorageRow(
              icon: LucideIcons.trash2,
              label: '删除选中 (${selected.length})',
              isDestructive: true,
              onTap: !enabled || selected.isEmpty
                  ? null
                  : () => confirmStorageAction(
                      context,
                      title: '删除选中话题',
                      message: '将永久移除选中的 ${selected.length} 个话题及消息，'
                          '包括其他分支。建议先备份。删除后可压缩数据库。',
                      action: () async {
                        await controller.deleteTopics(selected);
                        if (mounted) setState(_selected.clear);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
    return PopScope(
      canPop: !state.isBusy,
      child: Scaffold(
        appBar: const ModelSettingsAppBar(title: '聊天记录'),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  header,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: StorageDetails(
                      items: state.report?.itemsFor(StorageCategory.chat) ?? const [],
                      enabled: enabled,
                      onClean: controller.cleanItem,
                    ),
                  ),
                  if (state.isLoading || state.isBusy)
                    const LinearProgressIndicator(),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: StorageNotice(state.error!),
                    ),
                ],
              ),
            ),
            if (topics.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: StorageNotice('当前没有可列出的话题')),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final topic = topics[index];
                      return CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        value: selected.contains(topic.id),
                        title: Text(
                          topic.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${topic.assistantName}\n'
                          '${formatStorageBytes(topic.bytes)} · '
                          '${topic.messageCount} 条消息 · '
                          '${topic.imageCount} 个图片块'
                          ' · ${topic.videoCount} 个视频块',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            height: 1.3,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onChanged: !enabled
                            ? null
                            : (value) => setState(() {
                                if (value == true) {
                                  _selected.add(topic.id);
                                } else {
                                  _selected.remove(topic.id);
                                }
                              }),
                      );
                    },
                    childCount: topics.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
