import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/backup/application/storage_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_media.dart';
import 'package:aetherlink_flutter/features/backup/presentation/local_backup_page.dart';
import 'package:aetherlink_flutter/features/backup/presentation/storage_media_page.dart';
import 'package:aetherlink_flutter/features/backup/presentation/storage_widgets.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

class StorageCategoryPage extends ConsumerWidget {
  const StorageCategoryPage({required this.category, super.key});

  final StorageCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storageControllerProvider);
    final controller = ref.read(storageControllerProvider.notifier);
    final theme = Theme.of(context);
    final usage = state.report?.categories[category] ?? const StorageUsage();
    final isCacheUnavailable =
        category == StorageCategory.cache &&
        state.report?.canCleanCache != true;
    final target = switch (category) {
      StorageCategory.cache => StorageCleanup.cache,
      StorageCategory.workspaceHistory => StorageCleanup.workspaceHistory,
      _ => null,
    };
    final enabled = !state.isBusy && !state.isLoading;
    return PopScope(
      canPop: !state.isBusy,
      child: Scaffold(
        appBar: ModelSettingsAppBar(title: category.label),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StorageCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StorageUsageText(formatStorageBytes(usage.bytes)),
                        const SizedBox(height: 3),
                        Text(
                          '${usage.fileCount} 个文件',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            height: 1.3,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        StorageNotice(category.description),
                        if (isCacheUnavailable && state.report != null)
                          const StorageNotice(
                            '此平台的临时目录可能由多个应用共享，为避免影响其他程序，'
                            '不统计或清理临时目录及其网络图片缓存，仍可清理在线字体缓存。',
                          ),
                      ],
                    ),
                  ),
                  if (target != null) ...[
                    Divider(height: 1, color: theme.dividerColor),
                    StorageRow(
                      icon: LucideIcons.trash2,
                      label: '全部清理',
                      isDestructive: true,
                      onTap: !enabled
                          ? null
                          : () => confirmStorageCleanup(
                              context,
                              name: category.label,
                              action: () => controller.clean(target),
                            ),
                    ),
                  ],
                  if (category == StorageCategory.backups) ...[
                    Divider(height: 1, color: theme.dividerColor),
                    StorageRow(
                      icon: LucideIcons.archive,
                      label: '查看备份文件',
                      onTap: !enabled
                          ? null
                          : () async {
                              await openStoragePage(
                                context,
                                const LocalBackupPage(filesOnly: true),
                              );
                              await controller.refresh();
                            },
                    ),
                  ],
                  if (category == StorageCategory.terminal) ...[
                    Divider(height: 1, color: theme.dividerColor),
                    StorageRow(
                      icon: LucideIcons.terminal,
                      label: '进入终端管理环境',
                      onTap: !enabled
                          ? null
                          : () async {
                              await context.push<void>(AppRouter.terminalPath);
                              await controller.refresh();
                            },
                    ),
                  ],
                  if (category == StorageCategory.tools) ...[
                    for (final isImageView in [true, false]) ...[
                      Divider(height: 1, color: theme.dividerColor),
                      StorageRow(
                        icon: isImageView ? LucideIcons.image : LucideIcons.file,
                        label: isImageView ? '管理图片与截图' : '管理文件与视频',
                        onTap: !enabled
                            ? null
                            : () async {
                                await openStoragePage(context, StorageMediaPage(
                                  isImageView: isImageView,
                                  initialFilter: StorageMediaFilter.tools,
                                ));
                                await controller.refresh();
                              },
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            StorageDetails(
              items: state.report?.itemsFor(category) ?? const [],
              enabled: enabled,
              onClean: controller.cleanItem,
            ),
            if (state.isBusy || state.isLoading)
              const LinearProgressIndicator(),
            if (state.error != null) StorageNotice(state.error!),
          ],
        ),
      ),
    );
  }
}
