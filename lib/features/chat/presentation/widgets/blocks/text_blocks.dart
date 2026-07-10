import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/context_condense_service.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/deferred_content.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/message_selection_area.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/utils/regex_replacement.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

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
          builder: (_) => AppMarkdown(content: content, style: textStyle),
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
                builder: (_) => AppMarkdown(content: chunk, style: textStyle),
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

/// Target size (chars) of one markdown chunk — small enough that a single
/// chunk's parse + text layout fits a 120Hz frame's budget.
const int _kMarkdownChunkSize = 3000;

/// Chunk size for the *streaming* split: bounds how much text the active
/// tail re-parses per frame while keeping the widget count modest.
const int _kStreamingChunkSize = 512;

/// Renders a streaming markdown body as a column of paragraph chunks with
/// per-chunk widget reuse. During a stream the text is append-only, so every
/// chunk except the last is stable: its cached [AppMarkdown] instance is
/// returned identically, which makes Flutter skip that subtree's rebuild
/// entirely. Only the growing tail chunk is re-parsed on each delta.
class StreamingMarkdownBody extends StatefulWidget {
  const StreamingMarkdownBody({required this.content, this.style, super.key});

  final String content;
  final TextStyle? style;

  @override
  State<StreamingMarkdownBody> createState() => _StreamingMarkdownBodyState();
}

class _StreamingMarkdownBodyState extends State<StreamingMarkdownBody> {
  final List<String> _chunkTexts = [];
  final List<Widget> _chunkWidgets = [];
  TextStyle? _cachedStyle;

  @override
  Widget build(BuildContext context) {
    if (widget.style != _cachedStyle) {
      // Theme/style change invalidates every cached chunk.
      _cachedStyle = widget.style;
      _chunkTexts.clear();
      _chunkWidgets.clear();
    }
    final chunks = splitMarkdownChunks(
      widget.content,
      chunkSize: _kStreamingChunkSize,
    );
    if (chunks.length == 1) {
      _chunkTexts.clear();
      _chunkWidgets.clear();
      return AppMarkdown(content: chunks.first, style: widget.style);
    }
    if (_chunkTexts.length > chunks.length) {
      // Content was reset/shrunk (e.g. 重试) — drop stale cache entries.
      _chunkTexts.removeRange(chunks.length, _chunkTexts.length);
      _chunkWidgets.removeRange(chunks.length, _chunkWidgets.length);
    }
    for (var i = 0; i < chunks.length; i++) {
      final cached = i < _chunkTexts.length;
      if (cached && _chunkTexts[i] == chunks[i]) continue;
      final built = AppMarkdown(content: chunks[i], style: widget.style);
      if (cached) {
        _chunkTexts[i] = chunks[i];
        _chunkWidgets[i] = built;
      } else {
        _chunkTexts.add(chunks[i]);
        _chunkWidgets.add(built);
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List<Widget>.of(_chunkWidgets),
    );
  }
}

/// Splits [src] into rendering chunks of roughly [chunkSize] chars
/// (default [_kMarkdownChunkSize]).
///
/// Cuts only at blank-line paragraph boundaries that are *outside* fenced
/// code blocks, and never right before a continuation-looking line (list
/// item, indent, blockquote, table row) so lists / tables / quotes stay in
/// one chunk. Returns `[src]` unchanged when it's short enough.
List<String> splitMarkdownChunks(String src, {int? chunkSize}) {
  final minChunk = chunkSize ?? _kMarkdownChunkSize;
  if (src.length <= minChunk * 2) return [src];
  final lines = src.split('\n');
  final chunks = <String>[];
  final current = StringBuffer();
  var currentLen = 0;
  var inFence = false;

  bool isContinuation(String line) {
    final t = line.trimLeft();
    if (t.isEmpty) return false;
    if (line.startsWith(' ') || line.startsWith('\t')) return true;
    return t.startsWith('- ') ||
        t.startsWith('* ') ||
        t.startsWith('+ ') ||
        t.startsWith('>') ||
        t.startsWith('|') ||
        RegExp(r'^\d+[.)] ').hasMatch(t);
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final fenceMark = RegExp(r'^\s*(```|~~~)').hasMatch(line);
    if (fenceMark) inFence = !inFence;

    if (!inFence &&
        !fenceMark &&
        line.trim().isEmpty &&
        currentLen >= minChunk) {
      // Cut here unless the next non-empty line continues this construct.
      var j = i + 1;
      while (j < lines.length && lines[j].trim().isEmpty) {
        j++;
      }
      if (j >= lines.length || !isContinuation(lines[j])) {
        chunks.add(current.toString());
        current.clear();
        currentLen = 0;
        continue; // drop the separating blank line
      }
    }
    if (currentLen > 0) {
      current.write('\n');
      currentLen++;
    }
    current.write(line);
    currentLen += line.length;
  }
  if (currentLen > 0) chunks.add(current.toString());
  return chunks.isEmpty ? [src] : chunks;
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

/// Renders a `CONTEXT_SUMMARY` block: a compact card with the summary text
/// and compression stats. Defaults to collapsed (2-line preview + stats);
/// tapping the header expands to show the full summary.
/// Includes a "restore original" button when original message data is available.
class ContextSummaryBlockView extends ConsumerStatefulWidget {
  const ContextSummaryBlockView({required this.block, super.key});

  final ContextSummaryBlock block;

  @override
  ConsumerState<ContextSummaryBlockView> createState() =>
      _ContextSummaryBlockViewState();
}

class _ContextSummaryBlockViewState
    extends ConsumerState<ContextSummaryBlockView> {
  bool _showingSummary = false;
  bool _showingOriginal = false;
  bool _isRestoring = false;

  List<Map<String, dynamic>> get _originalMessages {
    final original = widget.block.metadata?['originalMessages'];
    if (original is List) return original.cast<Map<String, dynamic>>();
    return [];
  }

  bool get _canRestore => _originalMessages.isNotEmpty;

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复原文'),
        content: const Text('确定要恢复被压缩的原始消息吗？摘要将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);
    final service = ref.read(contextCondenseServiceProvider);
    final result = await service.restore(block: widget.block);
    if (!mounted) return;

    if (!result.success) {
      setState(() => _isRestoring = false);
      AppToast.error(context, result.error ?? '恢复失败');
    }
  }

  /// Build a formatted preview of the original messages.
  Widget _buildOriginalPreview(ThemeData theme, ColorScheme cs) {
    final messages = _originalMessages;
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final msg in messages) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg['role'] == 'user' ? '用户' : 'AI',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: msg['role'] == 'user'
                            ? cs.primary
                            : cs.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (msg['content'] as String? ?? '').length > 500
                          ? '${(msg['content'] as String).substring(0, 500)}…'
                          : msg['content'] as String? ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.1)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (tappable to toggle summary)
          GestureDetector(
            onTap: () => setState(() {
              _showingSummary = !_showingSummary;
              if (_showingSummary) _showingOriginal = false;
            }),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(LucideIcons.scrollText, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '上下文摘要',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _showingSummary
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),

          // Stats bar
          const SizedBox(height: 6),
          Text(
            '${widget.block.originalMessageCount} 条消息 → '
            '${widget.block.compressedTokens} tokens'
            '（节省 ${widget.block.tokensSaved}）',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),

          // Expanded summary content (tapping header toggles this)
          if (_showingSummary) ...[
            Divider(height: 16, color: cs.primary.withValues(alpha: 0.15)),
            AppMarkdown(content: widget.block.content),
          ],

          // Expanded original messages preview
          if (_showingOriginal) ...[
            Divider(height: 16, color: cs.primary.withValues(alpha: 0.15)),
            _buildOriginalPreview(theme, cs),
          ],

          // Action buttons
          if (_canRestore) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // Preview original button
                InkWell(
                  onTap: () => setState(() {
                    _showingOriginal = !_showingOriginal;
                    if (_showingOriginal) _showingSummary = false;
                  }),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showingOriginal
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,
                          size: 14,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showingOriginal ? '收起原文' : '预览原文',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Restore button
                _isRestoring
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : InkWell(
                        onTap: _restore,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.undo2,
                                size: 14,
                                color: cs.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '恢复原文',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders a `MEMORY_INJECTION` block: a compact chip showing how many
/// long-term memories were injected into this turn's system prompt. Defaults to
/// collapsed; tapping expands to list the injected memory contents so the user
/// can see exactly what the model was given — the 对话内「本轮注入 N 条记忆」块.
class MemoryInjectionBlockView extends StatefulWidget {
  const MemoryInjectionBlockView({required this.block, super.key});

  final MemoryInjectionBlock block;

  @override
  State<MemoryInjectionBlockView> createState() =>
      _MemoryInjectionBlockViewState();
}

class _MemoryInjectionBlockViewState extends State<MemoryInjectionBlockView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final memories = widget.block.memories;
    final hasDetail = memories.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: hasDetail
                ? () => setState(() => _expanded = !_expanded)
                : null,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(LucideIcons.brain, size: 15, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '本轮注入 ${widget.block.count} 条记忆',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                if (hasDetail)
                  Icon(
                    _expanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 15,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
          if (_expanded && hasDetail) ...[
            Divider(height: 14, color: cs.primary.withValues(alpha: 0.15)),
            for (var i = 0; i < memories.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      LucideIcons.dot,
                      size: 14,
                      color: cs.primary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      memories[i],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
