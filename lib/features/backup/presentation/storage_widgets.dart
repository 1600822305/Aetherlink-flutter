import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

extension StorageCategoryPresentation on StorageCategory {
  String get label => switch (this) {
    StorageCategory.chat => '聊天记录',
    StorageCategory.backups => '备份文件',
    StorageCategory.tools => '工具输出',
    StorageCategory.avatars => '头像',
    StorageCategory.fonts => '字体',
    StorageCategory.notes => '笔记',
    StorageCategory.cache => '缓存',
  };

  IconData get icon => switch (this) {
    StorageCategory.chat => LucideIcons.messagesSquare,
    StorageCategory.backups => LucideIcons.archive,
    StorageCategory.tools => LucideIcons.wrench,
    StorageCategory.avatars => LucideIcons.user,
    StorageCategory.fonts => LucideIcons.type,
    StorageCategory.notes => LucideIcons.notebookPen,
    StorageCategory.cache => LucideIcons.trash2,
  };

  Color get color => switch (this) {
    StorageCategory.chat => const Color(0xFF2563EB),
    StorageCategory.backups => const Color(0xFF7C3AED),
    StorageCategory.tools => const Color(0xFFEA580C),
    StorageCategory.avatars => const Color(0xFFDB2777),
    StorageCategory.fonts => const Color(0xFF0891B2),
    StorageCategory.notes => const Color(0xFF059669),
    StorageCategory.cache => const Color(0xFF64748B),
  };

  String get description => switch (this) {
    StorageCategory.chat =>
      '包含数据库、写入日志及共享内存文件。图片和视频内容也保存在聊天数据库中。',
    StorageCategory.backups => '已保存到本机的备份包。可进入文件列表查看时间、大小或移除旧备份。',
    StorageCategory.tools => '包括智能体工具生成的文件、浏览器截图和演示文稿快照。清理会使历史引用失效。',
    StorageCategory.avatars => '助手和用户使用的本地头像。请在相应资料设置中更换或移除。',
    StorageCategory.fonts => '包含自行导入的字体和在线字体下载缓存。下方操作仅移除在线字体缓存，保留导入字体。',
    StorageCategory.notes => '本地笔记文件。请在笔记中检查内容并按需删除，此处不批量移除笔记。',
    StorageCategory.cache => '应用临时目录中的文件。清理前请完成导入、导出和其他正在使用临时文件的任务。',
  };
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
    if (context.mounted) AppToast.success(context, '操作已完成，统计已更新');
  } catch (error) {
    if (context.mounted) AppToast.error(context, '操作未完成：$error');
  }
}
