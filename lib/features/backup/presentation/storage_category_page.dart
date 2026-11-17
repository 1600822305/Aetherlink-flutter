import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/storage_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';
import 'package:aetherlink_flutter/features/backup/presentation/local_backup_page.dart';
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
      StorageCategory.tools => StorageCleanup.tools,
      StorageCategory.fonts => StorageCleanup.fontCache,
      _ => null,
    };
    final enabled = !state.isBusy && !state.isLoading;
    final actionLabel = category == StorageCategory.fonts
        ? '清理在线字体缓存'
        : '清理${category.label}';
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
                            '不统计或清理其中的缓存。',
                          ),
                      ],
                    ),
                  ),
                  if (target != null && !isCacheUnavailable) ...[
                    Divider(height: 1, color: theme.dividerColor),
                    StorageRow(
                      icon: LucideIcons.trash2,
                      label: actionLabel,
                      isDestructive: true,
                      onTap: !enabled
                          ? null
                          : () => confirmStorageAction(
                              context,
                              title: actionLabel,
                              message: '${category.description}\n\n'
                                  '此操作将移除对应文件，无法撤销。确定继续吗？',
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
                ],
              ),
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
