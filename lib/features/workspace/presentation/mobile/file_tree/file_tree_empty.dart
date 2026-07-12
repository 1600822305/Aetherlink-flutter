import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The empty state shown when no workspace is open, pointing at the
/// open-folder sheet.
class FileTreeEmpty extends StatelessWidget {
  const FileTreeEmpty({super.key, required this.theme, required this.onOpen});

  final ThemeData theme;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.folderOpen,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '还没有打开工作区',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '点下方按钮，打开一个本地文件夹',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onOpen,
              icon: const Icon(LucideIcons.folderOpen, size: 18),
              label: const Text('打开文件夹'),
            ),
          ],
        ),
      ),
    );
  }
}
