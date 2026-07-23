// Tap-to-preview for chat `FILE` attachment blocks, reusing the existing
// viewers instead of new ones: text / code decodes to the workspace's
// virtualized [ReadOnlyCodeView] (syntax highlight by file name), images open
// in an [InteractiveViewer], and anything else (PDF / zip / …) falls back to
// the workspace-style "用其他应用打开" escape hatch via the OS share sheet.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/file_open_policy.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/read_only_code_view.dart';
import 'package:aetherlink_flutter/shared/utils/line_diff.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Opens a full-screen preview for [block]. Attachments ride inline as base64
/// (`ComposerAttachment` → FILE block), so the bytes decode locally without a
/// file layer.
Future<void> showFileBlockPreview(BuildContext context, FileBlock block) {
  FocusManager.instance.primaryFocus?.unfocus();
  // 零时长路由：与项目其它全屏子页一致（MaterialPageRoute 自带
  // 300ms transitionDuration，进入/返回都会卡一拍）。
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => _FileBlockPreviewPage(block: block),
    ),
  );
}

/// Inline base64 payload of a FILE block: the `file.base64Data` reference (a
/// data URI or bare base64) or a `data:` URL, decoded to bytes.
Uint8List? decodeFileBlockBytes(FileBlock block) {
  var data = block.file?.base64Data;
  if (data == null || data.isEmpty) {
    final url = block.url;
    if (url.startsWith('data:')) data = url;
  }
  if (data == null || data.isEmpty) return null;
  final comma = data.indexOf(',');
  final encoded = comma >= 0 ? data.substring(comma + 1) : data;
  if (encoded.isEmpty) return null;
  try {
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}

class _FileBlockPreviewPage extends ConsumerStatefulWidget {
  const _FileBlockPreviewPage({required this.block});

  final FileBlock block;

  @override
  ConsumerState<_FileBlockPreviewPage> createState() =>
      _FileBlockPreviewPageState();
}

enum _PreviewKind { text, image, unsupported, empty }

class _FileBlockPreviewPageState extends ConsumerState<_FileBlockPreviewPage> {
  late final Uint8List? _bytes = decodeFileBlockBytes(widget.block);
  late final _PreviewKind _kind = _classify();
  TextEditingController? _textController;
  double _fontSize = 14;

  _PreviewKind _classify() {
    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) return _PreviewKind.empty;
    final head = bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes;
    if (widget.block.mimeType.startsWith('image/') || looksImage(head)) {
      return _PreviewKind.image;
    }
    if (widget.block.mimeType.startsWith('text/') || !looksBinary(head)) {
      return _PreviewKind.text;
    }
    return _PreviewKind.unsupported;
  }

  @override
  void dispose() {
    _textController?.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/chat_attachment_share/${widget.block.name}',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      await ref.read(shareApiProvider).shareFiles([file.path]);
    } catch (e) {
      if (mounted) AppToast.error(context, '分享失败:$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.block.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_bytes != null)
            IconButton(
              onPressed: _share,
              icon: const Icon(LucideIcons.share2, size: 20),
              tooltip: '用其他应用打开',
            ),
        ],
      ),
      body: SafeArea(child: _body(theme)),
    );
  }

  Widget _body(ThemeData theme) {
    switch (_kind) {
      case _PreviewKind.image:
        return ColoredBox(
          color: Colors.black,
          child: SizedBox.expand(
            child: InteractiveViewer(
              maxScale: 8,
              child: Image.memory(
                _bytes!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _placeholder(
                  theme,
                  icon: LucideIcons.circleAlert,
                  text: '图片加载失败',
                ),
              ),
            ),
          ),
        );
      case _PreviewKind.text:
        final controller = _textController ??= TextEditingController(
          text: utf8.decode(_bytes!, allowMalformed: true),
        );
        return ReadOnlyCodeView(
          controller: controller,
          fontSize: _fontSize,
          onFontSize: (v) => setState(() => _fontSize = v),
          language: languageForFileName(widget.block.name),
        );
      case _PreviewKind.unsupported:
        return _placeholder(
          theme,
          icon: LucideIcons.fileQuestionMark,
          text: '该文件类型暂不支持内置预览\n可通过右上角分享用其他应用打开',
        );
      case _PreviewKind.empty:
        return _placeholder(
          theme,
          icon: LucideIcons.fileX2,
          text: '附件内容不可用（未随消息保存）',
        );
    }
  }

  Widget _placeholder(
    ThemeData theme, {
    required IconData icon,
    required String text,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
