import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/notes_sidebar_access.dart';
import 'package:aetherlink_flutter/features/notes/application/notes_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

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
    final customPath = ref.watch(notesStoragePathProvider);
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
            description: customPath == null
                ? '笔记以 .md 文件保存在应用默认目录'
                : '笔记保存在你选择的目录（可与其他应用共享）',
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
                Row(
                  children: [
                    ModelTonalButton(
                      icon: LucideIcons.folderOpen,
                      label: '更改目录',
                      onPressed: () => _changeDir(context, ref),
                    ),
                    if (customPath != null) ...[
                      const SizedBox(width: 8),
                      ModelTonalButton(
                        icon: LucideIcons.rotateCcw,
                        label: '恢复默认',
                        accent: theme.colorScheme.onSurfaceVariant,
                        onPressed: () => _resetDir(context, ref),
                      ),
                    ],
                  ],
                ),
                if (customPath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '提示：Android 上若所选目录无法访问，将自动回退到默认目录。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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
                CustomSwitch(
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
                _ToggleRow(
                  icon: LucideIcons.list,
                  label: '显示目录大纲',
                  description: '在编辑器顶栏显示大纲入口',
                  value: ref.watch(notesShowOutlineProvider),
                  onChanged: (v) =>
                      ref.read(notesShowOutlineProvider.notifier).set(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Android 任意目录（SAF）将在「工作区」功能就绪时一并上线。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _changeDir(BuildContext context, WidgetRef ref) async {
  final path = await FilePicker.getDirectoryPath(
    dialogTitle: '选择笔记存储目录',
  );
  if (path == null) return; // cancelled
  await ref.read(notesStoragePathProvider.notifier).setPath(path);
  if (!context.mounted) return;
  AppToast.success(context, '已更新存储目录');
}

Future<void> _resetDir(BuildContext context, WidgetRef ref) async {
  await ref.read(notesStoragePathProvider.notifier).setPath(null);
  if (!context.mounted) return;
  AppToast.success(context, '已恢复默认目录');
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
          CustomSwitch(value: value, onChanged: onChanged),
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
