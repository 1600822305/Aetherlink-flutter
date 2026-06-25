import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/notes_sidebar_access.dart';
import 'package:aetherlink_flutter/features/notes/application/notes_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// Notes settings — storage location and editor/display options.
///
/// MVP shows the active (app private) storage path; choosing a custom directory
/// (and the editor/display toggles) are later phases and render as disabled
/// "即将推出" placeholders, matching the app's existing convention.
class NotesSettingsPage extends ConsumerWidget {
  const NotesSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final store = ref.watch(notesFileStoreProvider);
    final sidebarTabEnabled = ref.watch(notesSidebarTabEnabledProvider);

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: '笔记设置'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _Card(
            title: '存储位置',
            description: '笔记以 .md 文件保存在此目录',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String>(
                  future: store.rootPath(),
                  builder: (context, snapshot) => Text(
                    snapshot.data ?? '加载中…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _PlaceholderRow(
                  icon: LucideIcons.folderOpen,
                  label: '更改存储目录',
                  description: '选择自定义目录（即将支持）',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: '侧边栏',
            description: '在聊天侧边栏快速进入笔记',
            child: Row(
              children: [
                Icon(
                  LucideIcons.panelLeft,
                  size: 20,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '显示笔记入口',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '在聊天侧边栏新增「笔记」Tab',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: sidebarTabEnabled,
                  onChanged: (v) =>
                      ref.read(notesSidebarTabToggleProvider).set(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: '编辑器',
            description: '默认打开方式与显示选项',
            child: Column(
              children: [
                const _PlaceholderRow(
                  icon: LucideIcons.pencilRuler,
                  label: '默认打开模式',
                  description: '源码 / 预览（即将支持）',
                ),
                Divider(height: 1, color: theme.dividerColor),
                const _PlaceholderRow(
                  icon: LucideIcons.type,
                  label: '字号',
                  description: '调整编辑器字号（即将支持）',
                ),
                Divider(height: 1, color: theme.dividerColor),
                const _PlaceholderRow(
                  icon: LucideIcons.list,
                  label: '显示目录大纲',
                  description: '在编辑器侧边显示大纲（即将支持）',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '更多功能（全文搜索、导入、自选目录、AI 自动命名、导出）将在后续版本陆续上线。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ModelSettingsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModelSectionTitle(title),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  const _PlaceholderRow({
    required this.icon,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
