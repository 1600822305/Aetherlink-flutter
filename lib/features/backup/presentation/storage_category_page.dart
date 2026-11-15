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
    final usage = state.report?.categories[category] ?? const StorageUsage();
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatStorageBytes(usage.bytes),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('${usage.fileCount} 个文件'),
                    StorageNotice(category.description),
                    if (target != null)
                      FilledButton.icon(
                        icon: const Icon(LucideIcons.trash2, size: 18),
                        label: Text(actionLabel),
                        onPressed: !enabled
                            ? null
                            : () => confirmStorageAction(
                                context,
                                title: actionLabel,
                                message: '${category.description}\n\n'
                                    '此操作将移除对应文件，无法撤销。确定继续吗？',
                                action: () => controller.clean(target),
                              ),
                      ),
                    if (category == StorageCategory.backups)
                      FilledButton.icon(
                        icon: const Icon(LucideIcons.archive, size: 18),
                        label: const Text('查看备份文件'),
                        onPressed: !enabled
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
                ),
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
