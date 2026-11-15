import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/storage_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';
import 'package:aetherlink_flutter/features/backup/presentation/diagnostic_page.dart';
import 'package:aetherlink_flutter/features/backup/presentation/storage_category_page.dart';
import 'package:aetherlink_flutter/features/backup/presentation/storage_widgets.dart';
import 'package:aetherlink_flutter/features/backup/presentation/topic_storage_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

class StorageSpacePage extends ConsumerStatefulWidget {
  const StorageSpacePage({super.key});

  @override
  ConsumerState<StorageSpacePage> createState() => _StorageSpacePageState();
}

class _StorageSpacePageState extends ConsumerState<StorageSpacePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(storageControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storageControllerProvider);
    final controller = ref.read(storageControllerProvider.notifier);
    final report = state.report;
    final enabled = !state.isBusy && !state.isLoading;
    return PopScope(
      canPop: !state.isBusy,
      child: Scaffold(
        appBar: const ModelSettingsAppBar(title: '存储空间'),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '合计 ${formatStorageBytes(report?.totalBytes ?? 0)}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: '重新统计',
                  onPressed: enabled ? controller.refresh : null,
                  icon: const Icon(LucideIcons.refreshCw),
                ),
              ],
            ),
            if (state.isLoading || state.isBusy)
              const LinearProgressIndicator(),
            if (state.error != null) StorageNotice('统计或维护遇到问题：${state.error}'),
            if (report != null) ...[
              const SizedBox(height: 16),
              StorageCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _StorageDistribution(report: report),
                ),
              ),
              const SizedBox(height: 16),
              StorageCard(
                child: Column(
                  children: [
                    for (final category in StorageCategory.values) ...[
                      if (category != StorageCategory.values.first)
                        const Divider(height: 1),
                      ListTile(
                        leading: Icon(category.icon, color: category.color),
                        title: Text(category.label),
                        subtitle: Text(
                          '${formatStorageBytes(report.categories[category]!.bytes)}'
                          ' · ${report.categories[category]!.fileCount} 个文件',
                        ),
                        trailing: const Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                        ),
                        onTap: !enabled
                            ? null
                            : () => openStoragePage(
                                context,
                                category == StorageCategory.chat
                                    ? const TopicStoragePage()
                                    : StorageCategoryPage(category: category),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            StorageCard(
              child: ListTile(
                leading: const Icon(LucideIcons.heartPulse),
                title: const Text('健康检查与孤儿数据修复'),
                subtitle: const Text('使用数据库诊断工具检查记录之间的关联'),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: !enabled
                    ? null
                    : () async {
                        await openStoragePage(context, const DiagnosticPage());
                        if (mounted) await controller.refresh();
                      },
              ),
            ),
            const StorageNotice('按本机文件长度统计；话题内容估算与数据库实际体积并不相等。'),
          ],
        ),
      ),
    );
  }
}

class _StorageDistribution extends StatelessWidget {
  const _StorageDistribution({required this.report});

  final StorageReport report;

  @override
  Widget build(BuildContext context) {
    final categories = StorageCategory.values;
    final shares = storageShares([
      for (final category in categories) report.categories[category]!.bytes,
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: double.infinity,
            height: 14,
            child: report.totalBytes == 0
                ? ColoredBox(color: Theme.of(context).dividerColor)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < categories.length; i++)
                        if (shares[i] > 0)
                          Expanded(
                            flex: (shares[i] * 10000)
                                .round()
                                .clamp(1, 10000)
                                .toInt(),
                            child: ColoredBox(color: categories[i].color),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final category in categories)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.circle, size: 10, color: category.color),
                  const SizedBox(width: 5),
                  Text(category.label),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
