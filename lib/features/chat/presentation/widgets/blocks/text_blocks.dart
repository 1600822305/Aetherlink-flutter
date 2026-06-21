import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';

/// Strips `<tool_use>...</tool_use>` spans the original removed before
/// rendering `main_text`.
final RegExp _toolUseTag = RegExp(
  r'<tool_use>[\s\S]*?</tool_use>',
  multiLine: true,
);

/// Strips `<tool_use>` spans and trims, matching the original's pre-render
/// cleanup. Exposed so the dispatcher can detect empty `main_text` blocks.
String cleanMainText(String content) =>
    content.replaceAll(_toolUseTag, '').trim();

/// Renders a `MAIN_TEXT` block as Markdown, mirroring `MainTextBlock.tsx`.
///
/// `renderUserInputAsMarkdown` defaults to true in the original, so user and
/// assistant text both render as Markdown. Returns nothing when the content is
/// empty after trimming.
class MainTextBlockView extends StatelessWidget {
  const MainTextBlockView({
    required this.block,
    this.textColor,
    this.onCitationTap,
    super.key,
  });

  final MainTextBlock block;
  final Color? textColor;
  final void Function(String citationId)? onCitationTap;

  @override
  Widget build(BuildContext context) {
    final cleaned = cleanMainText(block.content);
    if (cleaned.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return AppMarkdown(
      content: cleaned,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        height: 1.6,
      ),
      onCitationTap: onCitationTap,
    );
  }
}

/// Renders a standalone `MATH` block, mirroring `MathBlock.tsx`: the formula
/// centered in an outlined, subtly tinted card. The formula is handed to the
/// Markdown LaTeX engine via `$$...$$` (display) or `$...$` (inline).
class MathBlockView extends StatelessWidget {
  const MathBlockView({required this.block, super.key});

  final MathBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wrapped = block.displayMode
        ? '\$\$${block.content}\$\$'
        : '\$${block.content}\$';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Center(child: AppMarkdown(content: wrapped)),
    );
  }
}

/// Renders a `TRANSLATION` block, mirroring `TranslationBlock.tsx`: a divider
/// with a Languages icon that toggles a collapsible Markdown body. Shows a
/// spinner while the translation is still in flight.
class TranslationBlockView extends StatefulWidget {
  const TranslationBlockView({required this.block, super.key});

  final TranslationBlock block;

  @override
  State<TranslationBlockView> createState() => _TranslationBlockViewState();
}

class _TranslationBlockViewState extends State<TranslationBlockView> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = widget.block.content;
    final isTranslating = content.isEmpty || content == '翻译中...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: theme.dividerColor)),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                _expanded ? LucideIcons.languages : LucideIcons.languages,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
            Expanded(child: Divider(color: theme.dividerColor)),
          ],
        ),
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: isTranslating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : AppMarkdown(content: content),
          ),
          secondChild: const SizedBox(width: double.infinity),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

const List<int> _httpErrorCodes = [400, 401, 403, 404, 429, 500, 502, 503, 504];

const Map<int, String> _httpErrorMessages = {
  400: '请求无效（400）',
  401: '身份验证失败，请检查 API 密钥（401）',
  403: '没有访问权限（403）',
  404: '请求的资源不存在（404）',
  429: '请求过于频繁，请稍后再试（429）',
  500: '服务器内部错误（500）',
  502: '网关错误（502）',
  503: '服务暂时不可用（503）',
  504: '网关超时（504）',
};

/// The user-facing message for an [ErrorBlock], mirroring
/// `getUserFriendlyMessage` in `ErrorBlock.tsx`.
String _friendlyError(ErrorBlock block) {
  final code = int.tryParse(block.code ?? '');
  if (code != null && _httpErrorMessages.containsKey(code)) {
    return _httpErrorMessages[code]!;
  }
  final raw = block.message ?? block.content;
  if (raw.isNotEmpty) {
    for (final c in _httpErrorCodes) {
      if (raw.contains('$c')) return _httpErrorMessages[c]!;
    }
    return raw;
  }
  return '发生错误，请重试';
}

/// Renders an `ERROR` block, mirroring `ErrorBlock.tsx`: a clickable error
/// alert (red tint, alert icon, friendly message + 「详情」) that opens a detail
/// dialog with the raw error fields.
class ErrorBlockView extends StatelessWidget {
  const ErrorBlockView({required this.block, super.key});

  final ErrorBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _ErrorDetailDialog(block: block),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: errorColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: errorColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.circleAlert, size: 18, color: errorColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _friendlyError(block),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: errorColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '详情',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorDetailDialog extends StatelessWidget {
  const _ErrorDetailDialog({required this.block});

  final ErrorBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String?)>[
      ('错误信息', block.message),
      ('错误代码', block.code),
      ('详细信息', block.details),
      ('原始内容', block.content),
    ].where((r) => (r.$2 ?? '').isNotEmpty).toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(LucideIcons.circleAlert, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          const Text('错误详情'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, value) in rows) ...[
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(value!),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// Renders the streaming placeholder, mirroring `PlaceholderBlock.tsx`: a small
/// spinner and 「正在生成回复...」.
class PlaceholderBlockView extends StatelessWidget {
  const PlaceholderBlockView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(
          '正在生成回复...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Renders a `CONTEXT_SUMMARY` block, mirroring `ContextSummaryBlock.tsx`: a
/// compact card with the summary text and the compression stats.
class ContextSummaryBlockView extends StatelessWidget {
  const ContextSummaryBlockView({required this.block, super.key});

  final ContextSummaryBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.scrollText,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '上下文摘要',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppMarkdown(content: block.content),
          const SizedBox(height: 8),
          Text(
            '原始 ${block.originalMessageCount} 条 · 压缩 ${block.originalTokens} → '
            '${block.compressedTokens} tokens（节省 ${block.tokensSaved}）',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
