import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/storage_controller.dart';
import 'package:aetherlink_flutter/features/backup/application/storage_media_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

void listenStorageRefreshErrors(BuildContext context, WidgetRef ref) {
  void notify(String? previous, String? error) {
    if (error != null && context.mounted && ModalRoute.of(context)?.isCurrent == true) {
      AppToast.error(context, '刷新失败：$error');
    }
  }

  ref.listen<String?>(storageControllerProvider.select(
    (state) => state.report == null ? null : state.error,
  ), notify);
  ref.listen<String?>(storageMediaControllerProvider.select(
    (state) => state.hasLoaded ? state.error : null,
  ), notify);
}

extension StorageCategoryPresentation on StorageCategory {
  String get label => switch (this) {
    StorageCategory.chat => '聊天记录',
    StorageCategory.backups => '备份文件',
    StorageCategory.tools => '工具输出',
    StorageCategory.avatars => '头像',
    StorageCategory.fonts => '字体',
    StorageCategory.notes => '笔记',
    StorageCategory.cache => '缓存',
    StorageCategory.other => '其他',
    StorageCategory.workspaceHistory => '工作区历史',
    StorageCategory.terminal => '终端环境',
    StorageCategory.images => '图片',
    StorageCategory.files => '文件',
  };

  IconData get icon => switch (this) {
    StorageCategory.chat => LucideIcons.messagesSquare,
    StorageCategory.backups => LucideIcons.archive,
    StorageCategory.tools => LucideIcons.wrench,
    StorageCategory.avatars => LucideIcons.user,
    StorageCategory.fonts => LucideIcons.type,
    StorageCategory.notes => LucideIcons.notebookPen,
    StorageCategory.cache => LucideIcons.trash2,
    StorageCategory.other => LucideIcons.box,
    StorageCategory.workspaceHistory => LucideIcons.history,
    StorageCategory.terminal => LucideIcons.terminal,
    StorageCategory.images => LucideIcons.image,
    StorageCategory.files => LucideIcons.file,
  };

  Color get color => switch (this) {
    StorageCategory.chat => const Color(0xFF2563EB),
    StorageCategory.backups => const Color(0xFF7C3AED),
    StorageCategory.tools => const Color(0xFFEA580C),
    StorageCategory.avatars => const Color(0xFFDB2777),
    StorageCategory.fonts => const Color(0xFF0891B2),
    StorageCategory.notes => const Color(0xFF059669),
    StorageCategory.cache => const Color(0xFF64748B),
    StorageCategory.other => const Color(0xFF9333EA),
    StorageCategory.workspaceHistory => const Color(0xFFD97706),
    StorageCategory.terminal => const Color(0xFF0D9488),
    StorageCategory.images => const Color(0xFFE11D48),
    StorageCategory.files => const Color(0xFF4F46E5),
  };

  String get description => switch (this) {
    StorageCategory.chat =>
      '包含数据库、写入日志及共享内存文件。图片和视频内容也保存在聊天数据库中。',
    StorageCategory.backups => '已保存到本机的备份包。可进入文件列表查看时间、大小或移除旧备份。',
    StorageCategory.tools => '包括工具执行结果、浏览器截图和演示文稿快照。进入图片或文件管理可检查引用并移除未使用项目。',
    StorageCategory.avatars => '助手和用户使用的本地头像。请在相应资料设置中更换或移除。',
    StorageCategory.fonts => '自行导入的字体文件。在线字体下载缓存归入缓存类别，此处不提供批量清理。',
    StorageCategory.notes => '本地笔记文件。请在笔记中检查内容并按需删除，此处不批量移除笔记。',
    StorageCategory.cache => '包含临时文件、在线字体及网络图片缓存。临时目录不重复计算网络图片缓存。清理前请完成导入、导出等任务。',
    StorageCategory.other => 'PDF 引擎与下载的伙伴皮肤。现有管理器没有安全删除文件的接口，因此这里只展示占用。',
    StorageCategory.workspaceHistory => '文件修改前保存的本地版本。清理后无法通过文件历史恢复这些版本，不会删除工作区当前文件。',
    StorageCategory.terminal => '内置终端的系统文件与临时文件。系统文件仅展示，管理环境请进入终端；清理临时文件前请停止终端任务。',
    StorageCategory.images => '图片管理视图，占用已计入聊天记录、头像或工具输出，不重复累计。',
    StorageCategory.files => '文件与视频管理视图，占用已计入聊天记录或工具输出，不重复累计。',
  };
}

class StorageDetails extends StatelessWidget {
  const StorageDetails({
    required this.items,
    required this.enabled,
    required this.onClean,
    super.key,
  });

  final List<StorageItem> items;
  final bool enabled;
  final Future<void> Function(String) onClean;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '明细',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty) const StorageNotice('没有可显示的文件或目录'),
        for (final item in items) ...[
          StorageCard(
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
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatStorageBytes(item.usage.bytes),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.path,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.canClean) ...[
                  Divider(height: 1, color: theme.dividerColor),
                  StorageRow(
                    icon: LucideIcons.trash2,
                    label: '清理此项',
                    isDestructive: true,
                    onTap: !enabled
                        ? null
                        : () => confirmStorageCleanup(
                            context,
                            name: item.name,
                            action: () => onClean(item.id),
                          ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class StorageCard extends StatelessWidget {
  const StorageCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ModelSettingsCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class StorageRow extends StatelessWidget {
  const StorageRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
    this.accent,
    this.isDestructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? description;
  final Color? accent;
  final bool isDestructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : accent ?? theme.colorScheme.primary;
    final labelColor = isDestructive ? color : theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: onTap == null
                          ? theme.disabledColor
                          : labelColor,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.3,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class StorageUsageText extends StatelessWidget {
  const StorageUsageText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  );
}

class StorageNotice extends StatelessWidget {
  const StorageNotice(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.3,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

Future<void> openStoragePage(BuildContext context, Widget page) async {
  await Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => page,
    ),
  );
}

Future<void> confirmStorageAction(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() action,
  bool isDestructive = true,
  String successMessage = '操作已完成，统计已更新',
  String failurePrefix = '操作未完成：',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      actionsPadding: const EdgeInsets.all(8),
      titleTextStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 12.5,
        height: 1.3,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消', style: TextStyle(fontSize: 13)),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: isDestructive
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('继续', style: TextStyle(fontSize: 13)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await action();
    if (context.mounted) AppToast.success(context, successMessage);
  } catch (error) {
    if (context.mounted) AppToast.error(context, '$failurePrefix$error');
  }
}

Future<void> confirmStorageCleanup(
  BuildContext context, {
  required String name,
  required Future<void> Function() action,
}) => confirmStorageAction(
  context,
  title: '清理$name',
  message: '确定要清理 $name 吗？移除的文件无法恢复。',
  action: action,
  successMessage: '已清理 $name',
  failurePrefix: '清理失败：',
);
