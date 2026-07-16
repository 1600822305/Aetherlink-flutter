// 编辑器内的 Markdown 预览（README/文档）。渲染当前缓冲区内容（未保存的
// 编辑也实时可见），本地相对路径图片通过 backend 读字节渲染，网络图片走
// Image.network，链接外部打开。SAF 的 content:// 路径是 opaque 标识符，
// 无法做相对路径解析，本地图片显示占位提示。

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// Files this large aren't inlined as preview images (跨后端读字节较贵).
const int kMarkdownImageMaxBytes = 8 * 1024 * 1024;

/// Resolves a Markdown image [src] relative to the Markdown file at [mdPath].
/// Returns null when the src can't be resolved to a backend path:
/// http(s)/data URIs (rendered elsewhere), absolute-unsupported cases, or an
/// opaque (non-POSIX, e.g. SAF `content://`) [mdPath] that can't be joined.
String? resolveMarkdownImagePath(String mdPath, String src) {
  final trimmed = src.trim();
  if (trimmed.isEmpty) return null;
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('data:')) {
    return null;
  }
  // Opaque 路径（SAF content://）不能按 '/' 拼接解析。
  if (!mdPath.startsWith('/')) return null;
  final base = trimmed.startsWith('/')
      ? ''
      : mdPath.substring(0, mdPath.lastIndexOf('/'));
  final joined = trimmed.startsWith('/') ? trimmed : '$base/$trimmed';
  // 归一化 ./ 与 ../，越过根时视为无法解析。
  final parts = <String>[];
  for (final seg in joined.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (parts.isEmpty) return null;
      parts.removeLast();
    } else {
      parts.add(seg);
    }
  }
  if (parts.isEmpty) return null;
  // 丢掉 ?query / #fragment 尾巴（某些 README 图片带缓存参数）。
  final last = parts.removeLast().split(RegExp(r'[?#]')).first;
  return '/${[...parts, last].join('/')}';
}

/// Read-only Markdown rendering of [content]（编辑器预览态的正文区域）。
class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({
    super.key,
    required this.entry,
    required this.backend,
    required this.content,
    required this.fontSize,
  });

  final WorkspaceEntry entry;
  final WorkspaceBackend backend;
  final String content;
  final double fontSize;

  static void _openLink(String url, String _) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: fontSize,
      height: 1.5,
    );
    final baseSize = fontSize;
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: GptMarkdownTheme(
          gptThemeData: GptMarkdownThemeData(
            brightness: theme.brightness,
            h1: baseStyle?.copyWith(
              fontSize: baseSize * 1.8,
              fontWeight: FontWeight.bold,
            ),
            h2: baseStyle?.copyWith(
              fontSize: baseSize * 1.5,
              fontWeight: FontWeight.bold,
            ),
            h3: baseStyle?.copyWith(
              fontSize: baseSize * 1.2,
              fontWeight: FontWeight.w600,
            ),
            h4: baseStyle?.copyWith(
              fontSize: baseSize * 1.0,
              fontWeight: FontWeight.w600,
            ),
            h5: baseStyle?.copyWith(
              fontSize: baseSize * 0.9,
              fontWeight: FontWeight.w600,
            ),
            h6: baseStyle?.copyWith(
              fontSize: baseSize * 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: GptMarkdown(
            content,
            style: baseStyle,
            onLinkTap: _openLink,
            codeBuilder: (context, name, code, closed) =>
                _CodeBlock(language: name, code: code),
            highlightBuilder: (context, text, style) => _InlineCode(
              text: text,
              style: style,
            ),
            imageBuilder: (context, url, width, height) => _MarkdownImage(
              src: url,
              mdPath: entry.path,
              backend: backend,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fenced code block：等宽字体 + 淡底 + 圆角（跟编辑器风格一致的轻量版）。
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.language, required this.code});

  final String language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (language.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                language,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Text(
              code,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontFamilyFallback: const ['monospace'],
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineCode extends StatelessWidget {
  const _InlineCode({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: style.copyWith(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['monospace'],
        ),
      ),
    );
  }
}

/// Markdown 图片：网络/data URI 直接渲染；相对路径经 backend 读字节；
/// 解析不了（SAF opaque 路径、越界 ../）给占位提示。
class _MarkdownImage extends StatefulWidget {
  const _MarkdownImage({
    required this.src,
    required this.mdPath,
    required this.backend,
  });

  final String src;
  final String mdPath;
  final WorkspaceBackend backend;

  @override
  State<_MarkdownImage> createState() => _MarkdownImageState();
}

class _MarkdownImageState extends State<_MarkdownImage> {
  Future<Uint8List?>? _load;

  @override
  void initState() {
    super.initState();
    final resolved = resolveMarkdownImagePath(widget.mdPath, widget.src);
    if (resolved != null) _load = _read(resolved);
  }

  Future<Uint8List?> _read(String path) async {
    try {
      final info = await widget.backend.getFileInfo(path);
      if (info.isDirectory || info.size > kMarkdownImageMaxBytes) return null;
      return Uint8List.fromList(await widget.backend.readFileBytes(path));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lower = widget.src.trim().toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return Image.network(
        widget.src.trim(),
        errorBuilder: (context, error, stack) => _placeholder(theme),
      );
    }
    if (lower.startsWith('data:')) {
      final comma = widget.src.indexOf(',');
      if (comma > 0 && lower.contains(';base64,')) {
        try {
          return Image.memory(
            base64Decode(widget.src.substring(comma + 1).trim()),
            errorBuilder: (context, error, stack) => _placeholder(theme),
          );
        } catch (_) {}
      }
      return _placeholder(theme);
    }
    final load = _load;
    if (load == null) return _placeholder(theme);
    return FutureBuilder<Uint8List?>(
      future: load,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final bytes = snap.data;
        if (bytes == null) return _placeholder(theme);
        return Image.memory(
          bytes,
          errorBuilder: (context, error, stack) => _placeholder(theme),
        );
      },
    );
  }

  Widget _placeholder(ThemeData theme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.imageOff,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                widget.src,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
}
