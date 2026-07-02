import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/core/platform/file_system_api.dart';
import 'package:aetherlink_flutter/features/knowledge/data/pdfium_engine_manager.dart';

/// 弹出 PDFium 引擎安装面板；装好返回 `true`，取消/失败关闭返回 `false`。
Future<bool> showPdfiumEngineSetupSheet(
  BuildContext context,
  FileSystemApi fileSystem,
) async {
  final installed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => PdfiumEngineSetupSheet(fileSystem: fileSystem),
  );
  return installed ?? false;
}

/// PDF 解析引擎（PDFium）按需安装面板：引擎不随安装包内置（约 6MB），
/// 首次加 PDF 时在这里在线下载（地址可换成任意直链镜像）或手动导入
/// 群里 / 云盘分发的 .tgz / 库文件。
class PdfiumEngineSetupSheet extends StatefulWidget {
  const PdfiumEngineSetupSheet({super.key, required this.fileSystem});

  final FileSystemApi fileSystem;

  @override
  State<PdfiumEngineSetupSheet> createState() => _PdfiumEngineSetupSheetState();
}

class _PdfiumEngineSetupSheetState extends State<PdfiumEngineSetupSheet> {
  late final TextEditingController _urlController;
  CancelToken? _cancelToken;
  double? _progress;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: PdfiumEngineManager.defaultDownloadUrl?.toString() ?? '',
    );
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
      _cancelToken = cancelToken;
    });
    try {
      await PdfiumEngineManager.instance.download(
        url: url,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = received / total);
        },
      );
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
      await PdfiumEngineManager.instance.installFromFile(picked.path);
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
              '安装 PDF 解析引擎',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '本地解析 PDF 需要 PDFium 引擎（约 6MB），为控制安装包体积未随应用'
              '内置，只需安装一次。可在线下载官方预编译包（下载地址可替换为'
              '网盘等镜像直链），也可以导入别人分享的引擎文件（.tgz 或 '
              'libpdfium.so）。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
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
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _progress == null
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
