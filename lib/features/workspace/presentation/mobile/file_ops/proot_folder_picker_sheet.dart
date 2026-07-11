// IDE 式文件夹选择器（内置终端 rootfs 内）——「打开项目文件夹」不再要求用户
// 手输路径/项目名，而是像 IDE 一样浏览目录树选一个文件夹：可逐级进入子目录、
// 返回上级、就地新建文件夹，最后「在此打开」把工作区锚定到当前目录。
//（双作用域设计稿 §2.2 的项目模式入口交互升级。）

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// 选择结果：目录 guest 路径 + 是否开启独立 HOME（L2 语言级隔离）。
class ProotFolderPick {
  const ProotFolderPick({required this.path, required this.isolatedHome});

  final String path;
  final bool isolatedHome;
}

/// Shows the rootfs folder browser anchored at [initialPath]; resolves to the
/// picked folder, or null when the user bails out.
Future<ProotFolderPick?> showProotFolderPickerSheet(
  BuildContext context, {
  required WorkspaceBackend backend,
  required String initialPath,
}) {
  return showModalBottomSheet<ProotFolderPick>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _ProotFolderPickerSheet(
      backend: backend,
      initialPath: initialPath,
    ),
  );
}

class _ProotFolderPickerSheet extends StatefulWidget {
  const _ProotFolderPickerSheet({
    required this.backend,
    required this.initialPath,
  });

  final WorkspaceBackend backend;
  final String initialPath;

  @override
  State<_ProotFolderPickerSheet> createState() =>
      _ProotFolderPickerSheetState();
}

class _ProotFolderPickerSheetState extends State<_ProotFolderPickerSheet> {
  late String _path = widget.initialPath;
  bool _isolatedHome = false;
  late Future<List<WorkspaceEntry>> _entries = _load();

  Future<List<WorkspaceEntry>> _load() async {
    final entries = await widget.backend.listDir(_path);
    final dirs = entries.where((e) => e.isDirectory).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return dirs;
  }

  void _goTo(String path) {
    setState(() {
      _path = path;
      _entries = _load();
    });
  }

  String get _parentPath {
    final idx = _path.lastIndexOf('/');
    if (idx <= 0) return '/';
    return _path.substring(0, idx);
  }

  Future<void> _createFolder() async {
    final name = await _promptFolderName(context);
    if (name == null || !mounted) return;
    try {
      final created = await widget.backend.createDirectory(_path, name);
      if (!mounted) return;
      _goTo(created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('新建失败 · $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atRoot = _path == '/';
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                '选择项目文件夹',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // 当前路径 + 返回上级 / 新建文件夹。
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '上一级',
                    onPressed: atRoot ? null : () => _goTo(_parentPath),
                    icon: const Icon(LucideIcons.arrowUp, size: 20),
                  ),
                  Expanded(
                    child: Text(
                      _path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '新建文件夹',
                    onPressed: _createFolder,
                    icon: const Icon(LucideIcons.folderPlus, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: FutureBuilder<List<WorkspaceEntry>>(
                future: _entries,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '读取目录失败 · ${snapshot.error}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final dirs = snapshot.data!;
                  if (dirs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          '空目录 · 可直接「在此打开」或新建文件夹',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: dirs.length,
                    itemBuilder: (context, i) {
                      final d = dirs[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          LucideIcons.folder,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(LucideIcons.chevronRight, size: 16),
                        onTap: () => _goTo(d.path),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('独立环境（HOME 隔离）'),
                        Text(
                          'rc 文件 / 全局配置 / 缓存按项目隔离',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CustomSwitch(
                    value: _isolatedHome,
                    onChanged: (v) => setState(() => _isolatedHome = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(
                    ProotFolderPick(
                      path: _path,
                      isolatedHome: _isolatedHome,
                    ),
                  ),
                  icon: const Icon(LucideIcons.folderOpen, size: 18),
                  label: const Text('在此打开'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Allowed folder name: no path separators / traversal.
final RegExp _kFolderNamePattern = RegExp(r'^[\w][\w.-]*$');

Future<String?> _promptFolderName(BuildContext context) async {
  final controller = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '如 my-app'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (!_kFolderNamePattern.hasMatch(name)) return;
              Navigator.of(dialogContext).pop(name);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
