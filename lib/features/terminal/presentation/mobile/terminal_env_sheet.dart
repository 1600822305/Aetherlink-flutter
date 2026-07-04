// 内置终端「环境」面板（P2）：软件源切换（国内镜像）+ 常用环境一键装
// （python / node / git / 构建工具），按已装发行版（Alpine/Ubuntu）适配
// apk/apt 命令。命令直接回放进当前交互式终端会话，用户在终端里实时
// 看到安装过程。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_distro.dart';
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
  TerminalDistro _distro = TerminalDistro.alpine;
  bool _sdcardMounted = false;

  @override
  void initState() {
    super.initState();
    TerminalEngineManager.instance.installedDistro().then((distro) {
      if (mounted && distro != null) setState(() => _distro = distro);
    });
    TerminalEngineManager.instance.sdcardMountEnabled().then((enabled) {
      if (mounted) setState(() => _sdcardMounted = enabled);
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Android 11+ 要「所有文件访问」才能直接读写 /storage/emulated/0；
  /// 低版本走传统存储权限兜底。
  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    if ((await Permission.manageExternalStorage.request()).isGranted) {
      return true;
    }
    if ((await Permission.storage.request()).isGranted) return true;
    return false;
  }

  Future<void> _toggleSdcardMount(bool enable) async {
    if (enable && !await _ensureStoragePermission()) {
      if (!mounted) return;
      _snack(
        '需要「所有文件访问」权限：请在系统设置 → 应用 → 本应用 → 权限 里开启后重试。',
      );
      await openAppSettings();
      return;
    }
    await TerminalEngineManager.instance.setSdcardMountEnabled(enable);
    if (!mounted) return;
    setState(() => _sdcardMounted = enable);
    _snack(enable ? '已开启，重新进入终端后 /sdcard 生效' : '已关闭，新会话生效');
  }

  void _run(String command) {
    widget.onRunCommand(command);
    Navigator.of(context).pop();
  }

  Future<void> _switchMirror(TerminalMirror mirror) async {
    setState(() => _switchingMirror = true);
    try {
      await TerminalEngineManager.instance.setPackageMirror(mirror);
      if (!mounted) return;
      // 切完源立刻刷新索引，让用户在终端里看到生效。
      _run(refreshIndexCommandFor(_distro));
    } catch (e) {
      if (!mounted) return;
      setState(() => _switchingMirror = false);
      _snack('切换失败：$e');
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
            for (final preset in quickInstallsFor(_distro))
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
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(LucideIcons.hardDrive, size: 20),
              title: const Text('挂载手机存储'),
              subtitle: const Text('把手机存储映射到 /sdcard（需所有文件访问权限，新会话生效）'),
              value: _sdcardMounted,
              onChanged: _toggleSdcardMount,
            ),
            const Divider(height: 24),
            Text(
              _distro == TerminalDistro.ubuntu ? 'apt 软件源' : 'apk 软件源',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _distro == TerminalDistro.ubuntu
                  ? '国内网络建议切换到镜像源，apt-get install 会快很多。'
                  : '国内网络建议切换到镜像源，apk add 会快很多。',
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
