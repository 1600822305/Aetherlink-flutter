// 内置终端首次引导面板：下载并安装 Alpine rootfs（对标 PDFium 引擎安装面板）。
// rootfs 不随安装包内置（下载约 3~4MB）；装好后「打开工作区」面板的内置终端
// 入口直接进入，无需再次安装。

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/core/platform/file_system_api.dart';
import 'package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';

/// 弹出内置终端环境安装面板；装好返回 `true`，取消/失败关闭返回 `false`。
Future<bool> showTerminalSetupSheet(
  BuildContext context,
  FileSystemApi fileSystem,
) async {
  final installed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => TerminalSetupSheet(fileSystem: fileSystem),
  );
  return installed ?? false;
}

class TerminalSetupSheet extends StatefulWidget {
  const TerminalSetupSheet({super.key, required this.fileSystem});

  final FileSystemApi fileSystem;

  @override
  State<TerminalSetupSheet> createState() => _TerminalSetupSheetState();
}

class _TerminalSetupSheetState extends State<TerminalSetupSheet> {
  late final TextEditingController _urlController;
  TerminalMirror _mirror = kTerminalMirrors.first;
  CancelToken? _cancelToken;
  double? _progress;
  bool _busy = false;
  bool _extracting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: TerminalEngineManager.defaultRootfsUrl?.toString() ?? '',
    );
  }

  void _selectMirror(TerminalMirror mirror) {
    setState(() {
      _mirror = mirror;
      _urlController.text =
          TerminalEngineManager.rootfsUrlForMirror(mirror)?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    final url = Uri.tryParse(_urlController.text.trim());
    if (url == null || !url.hasScheme) {
      setState(() => _error = '下载地址无效');
      return;
    }
    final cancelToken = CancelToken();
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
      _extracting = false;
      _cancelToken = cancelToken;
    });
    try {
      await TerminalEngineManager.instance.download(
        url: url,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          final progress = received / total;
          setState(() {
            _progress = progress;
            if (progress >= 1) _extracting = true;
          });
        },
      );
      // apk 源跟随下载镜像：选了国内镜像就把 rootfs 内 /etc/apk/repositories
      // 一并切过去（并启用 community 仓），apk add 才不会卡在官方源。
      await TerminalEngineManager.instance.setApkMirror(_mirror);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.type == DioExceptionType.cancel ? null : '下载失败：$e';
      });
    } catch (e) {
      if (mounted) setState(() => _error = '安装失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
          _extracting = false;
          _cancelToken = null;
        });
      }
    }
  }

  Future<void> _importFromFile() async {
    final picked = await widget.fileSystem.pickFile();
    if (picked == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await TerminalEngineManager.instance.installFromFile(picked.path);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = '导入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '安装内置终端环境',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '内置终端在应用内运行一个完整的 Alpine Linux（PRoot 方案，免 Root、'
              '不依赖 Termux）。首次使用需下载系统镜像（约 3MB，解压后 ~10MB），'
              '只装一次。下载地址可替换为网盘等镜像直链，也可导入别人分享的 '
              'rootfs 包（.tar.gz）。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final mirror in kTerminalMirrors)
                  ChoiceChip(
                    label: Text(mirror.name),
                    selected: _mirror.id == mirror.id,
                    onSelected: _busy ? null : (_) => _selectMirror(mirror),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '下载地址',
                hintText: 'https://...',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_busy && _cancelToken != null) ...[
              LinearProgressIndicator(value: _extracting ? null : _progress),
              const SizedBox(height: 8),
              Text(
                _extracting
                    ? '正在解压…'
                    : _progress == null
                        ? '正在下载…'
                        : '正在下载… ${(_progress! * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _cancelToken?.cancel(),
                child: const Text('取消下载'),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: _busy ? null : _download,
                icon: const Icon(LucideIcons.download, size: 18),
                label: const Text('在线下载并安装'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _importFromFile,
                icon: const Icon(LucideIcons.fileInput, size: 18),
                label: const Text('从文件导入'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
