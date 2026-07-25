import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/deferred_content.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/message_selection_area.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/utils/regex_replacement.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/markdown_body.dart';

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
/// When the 「消息可选中复制」 setting (`selectableMessageText`) is on, the
/// rendered body is wrapped in a [SelectionArea] so it can be long-press
/// selected and copied.
///
/// User messages honor the 「渲染用户输入」 setting
/// (`renderUserInputAsMarkdown`): when off they are shown as plain selectable
/// text; assistant text always renders as Markdown. Returns nothing when the
/// content is empty after trimming.
///
/// Before rendering, the current assistant's 正则规则 are applied for display
/// (all rules, including `visualOnly`), scoped by [role] — the port of the web
/// `applyRegexRulesForDisplay` step in `MainTextBlock.tsx`.
class MainTextBlockView extends ConsumerWidget {
  const MainTextBlockView({
    required this.block,
    this.role,
    this.textColor,
    super.key,
  });

  final MainTextBlock block;
  final MessageRole? role;
  final Color? textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var cleaned = cleanMainText(block.content);
    if (cleaned.isEmpty) return const SizedBox.shrink();

    final scope = switch (role) {
      MessageRole.user => AssistantRegexScope.user,
      MessageRole.assistant => AssistantRegexScope.assistant,
      _ => null,
    };
    if (scope != null) {
      final rules = ref.watch(
        currentAssistantProvider.select((a) => a?.regexRules),
      );
      if (rules != null && rules.isNotEmpty) {
        cleaned = applyRegexRulesForDisplay(cleaned, rules, scope);
        if (cleaned.isEmpty) return const SizedBox.shrink();
      }
    }

    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: textColor,
      height: 1.6,
    );

    final selectable = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.selectableMessageText),
    );

    if (role == MessageRole.user) {
      final renderAsMarkdown = ref.watch(
        sidebarSettingsControllerProvider.select(
          (s) => s.renderUserInputAsMarkdown,
        ),
      );
      if (!renderAsMarkdown) {
        return SelectableText(cleaned, style: textStyle);
      }
    }

    // A very long finished markdown body (e.g. multi-round tool-call answers
    // stacked in one bubble) can blow a frame's build budget on its own —
    // deferring it as a single unit only moves the spike to whichever frame
    // materializes it. Split it into fence-aware paragraph chunks instead:
    // each chunk parses + lays out independently under the scheduler's
    // per-frame budget, so no single frame ever pays for the whole body.
    // Streaming text always renders inline.
    final content = cleaned;
    Widget body;
    if (kTerminalBlockStatuses.contains(block.status)) {
      final fontSize = textStyle?.fontSize ?? 14;
      final lineHeight = fontSize * 1.6;
      final chunks = splitMarkdownChunks(content);
      if (chunks.length == 1) {
        body = DeferredContent(
          cost: content.length,
          estimatedHeight: content.length / 22 * lineHeight,
          builder: (_) => finishedMarkdown(content, textStyle),
        );
      } else {
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final chunk in chunks)
              DeferredContent(
                cost: chunk.length,
                estimatedHeight: chunk.length / 22 * lineHeight,
                builder: (_) => finishedMarkdown(chunk, textStyle),
              ),
          ],
        );
      }
    } else {
      // Streaming: Streamdown-style block memoization — the body is split at
      // stable paragraph boundaries and earlier blocks reuse their previously
      // built widget instance, so each delta re-parses only the active tail
      // instead of the whole reply (O(tail) per frame instead of O(n)).
      body = StreamingMarkdownBody(content: content, style: textStyle);
    }
    return selectable ? MessageSelectionArea(child: body) : body;
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
