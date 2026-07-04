// 内置终端「环境」面板（P2）：apk 源切换（国内镜像）+ 常用环境一键装
// （python / node / git / 构建工具）。命令直接回放进当前交互式终端会话，
// 用户在终端里实时看到安装过程。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';

/// 弹出环境面板。[onRunCommand] 把一条命令送进当前终端会话（自动补 `\n`）。
Future<void> showTerminalEnvSheet(
  BuildContext context, {
  required void Function(String command) onRunCommand,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _TerminalEnvSheet(onRunCommand: onRunCommand),
  );
}

class _TerminalEnvSheet extends StatefulWidget {
  const _TerminalEnvSheet({required this.onRunCommand});

  final void Function(String command) onRunCommand;

  @override
  State<_TerminalEnvSheet> createState() => _TerminalEnvSheetState();
}

class _TerminalEnvSheetState extends State<_TerminalEnvSheet> {
  bool _switchingMirror = false;

  void _run(String command) {
    widget.onRunCommand(command);
    Navigator.of(context).pop();
  }

  Future<void> _switchMirror(TerminalMirror mirror) async {
    setState(() => _switchingMirror = true);
    try {
      await TerminalEngineManager.instance.setApkMirror(mirror);
      if (!mounted) return;
      // 切完源立刻刷新索引，让用户在终端里看到生效。
      _run('apk update');
    } catch (e) {
      if (!mounted) return;
      setState(() => _switchingMirror = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切换失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '常用环境一键装',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final preset in kTerminalQuickInstalls)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.package, size: 20),
                title: Text(preset.label),
                subtitle: Text(
                  '${preset.description} · ${preset.command}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(LucideIcons.play, size: 16),
                onTap: () => _run(preset.command),
              ),
            const Divider(height: 24),
            Text(
              'apk 软件源',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '国内网络建议切换到镜像源，apk add 会快很多。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final mirror in kTerminalMirrors)
                  ActionChip(
                    label: Text(mirror.name),
                    onPressed:
                        _switchingMirror ? null : () => _switchMirror(mirror),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
