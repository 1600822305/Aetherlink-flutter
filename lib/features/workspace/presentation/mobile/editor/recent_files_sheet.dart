// Bottom sheet listing the current workspace's recently opened files
// ([recentFilesProvider]), so a closed tab can be found again. Tapping an
// entry re-opens it in a tab; stale entries (deleted/moved files) surface the
// editor's normal load-error state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_registry.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/readable_path.dart';

Future<void> showRecentFilesSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final theme = Theme.of(context);
        final recent = ref.watch(recentFilesProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '最近打开',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Text(
                    '暂无记录,打开过的文件会出现在这里。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: recent.length,
                    itemBuilder: (context, i) {
                      final entry = recent[i];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: const Icon(LucideIcons.fileText, size: 18),
                        title: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          readableWorkspacePath(entry.path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          ref.read(openWorkspaceFilesProvider.notifier).open(
                                entry,
                                dirtyPaths: ref.read(dirtyFilesProvider),
                              );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
