import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';

/// A compact, special-purpose rendering of `builtin_web_search` tool results.
///
/// States:
///   * **searching** — spinner + "正在搜索..."
///   * **done** — compact header (result count + favicons), tap to expand list
///   * **error** — one-line error message
class WebSearchBlockView extends StatefulWidget {
  const WebSearchBlockView({required this.block, super.key});

  final ToolBlock block;

  @override
  State<WebSearchBlockView> createState() => _WebSearchBlockViewState();
}

class _WebSearchBlockViewState extends State<WebSearchBlockView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = widget.block.status;
    final isProcessing = status == MessageBlockStatus.pending ||
        status == MessageBlockStatus.processing ||
        status == MessageBlockStatus.streaming;
    final hasError = status == MessageBlockStatus.error;

    final query = _extractQuery(widget.block.arguments);
    final results = hasError ? const <_SearchResult>[] : _parseResults(widget.block.content);

    final bgColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — always visible
          _buildHeader(
            context,
            isProcessing: isProcessing,
            hasError: hasError,
            query: query,
            resultCount: results.length,
          ),
          // Expanded results list
          if (_expanded && results.isNotEmpty)
            _buildResultsList(context, results),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required bool isProcessing,
    required bool hasError,
    required String query,
    required int resultCount,
  }) {
    final theme = Theme.of(context);

    if (isProcessing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '正在搜索${query.isNotEmpty ? '「$query」' : ''}...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(LucideIcons.circleAlert, size: 14, color: theme.colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '搜索失败',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Success state — tappable header
    return InkWell(
      onTap: resultCount > 0
          ? () => setState(() => _expanded = !_expanded)
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              LucideIcons.globe,
              size: 15,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            if (resultCount > 0) ...[
              Text(
                '$resultCount 条搜索结果',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              Text(
                '未找到搜索结果',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Spacer(),
            if (resultCount > 0)
              AnimatedRotation(
                turns: _expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  LucideIcons.chevronRight,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, List<_SearchResult> results) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: [
          for (var i = 0; i < results.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 12, endIndent: 12, color: theme.dividerColor.withValues(alpha: 0.3)),
            _SearchResultTile(result: results[i], index: i + 1),
          ],
        ],
      ),
    );
  }
}

/// One search result row in the expanded list.
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.index});

  final _SearchResult result;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hostname = _extractHostname(result.url);

    return InkWell(
      onTap: () async {
        final uri = Uri.tryParse(result.url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index number
            SizedBox(
              width: 20,
              child: Text(
                '$index',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Favicon
            _Favicon(hostname: hostname, size: 14),
            const SizedBox(width: 8),
            // Title + domain
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title.isNotEmpty ? result.title : hostname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hostname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            // External link icon
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Icon(
                LucideIcons.externalLink,
                size: 11,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays a site favicon with a globe fallback.
class _Favicon extends StatelessWidget {
  const _Favicon({required this.hostname, this.size = 14});

  final String hostname;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (hostname.isEmpty) return _fallback(context);
    final url = 'https://www.google.com/s2/favicons?domain=$hostname&sz=32';
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.network(
        url,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Icon(
      LucideIcons.globe,
      size: size - 2,
      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    );
  }
}

// ---------------------------------------------------------------------------
// Parsing helpers
// ---------------------------------------------------------------------------

class _SearchResult {
  const _SearchResult({
    required this.title,
    required this.url,
    this.snippet = '',
  });

  final String title;
  final String url;
  final String snippet;
}

/// Extracts the search query from the tool-call arguments.
String _extractQuery(Map<String, dynamic>? args) {
  if (args == null) return '';
  return (args['query'] as String?) ?? '';
}

/// Parses the Markdown content returned by [SearchHelpers.formatResults]
/// into a list of [_SearchResult].
///
/// The format is:
/// ```
/// ### 1. Title
///
/// **链接**: https://example.com
///
/// **摘要**: Some text...
/// ```
List<_SearchResult> _parseResults(Object? content) {
  if (content == null) return const [];
  final text = content is String ? content : content.toString();
  if (text.isEmpty) return const [];

  final results = <_SearchResult>[];
  // Match each numbered result section
  final sectionPattern = RegExp(
    r'###\s*\d+\.\s*(.+?)(?:\n|\r\n)'  // title line
    r'([\s\S]*?)'                        // body until next ### or end
    r'(?=###\s*\d+\.|---\s*\n\*数据来源|$)',
    multiLine: true,
  );

  for (final match in sectionPattern.allMatches(text)) {
    final title = match.group(1)?.trim() ?? '';
    final body = match.group(2) ?? '';

    final urlMatch = RegExp(r'\*\*链接\*\*:\s*(\S+)').firstMatch(body);
    final snippetMatch = RegExp(r'\*\*摘要\*\*:\s*(.+?)(?:\n\n|\n---|$)', dotAll: true).firstMatch(body);

    final url = urlMatch?.group(1)?.trim() ?? '';
    final snippet = snippetMatch?.group(1)?.trim() ?? '';

    if (url.isNotEmpty || title.isNotEmpty) {
      results.add(_SearchResult(title: title, url: url, snippet: snippet));
    }
  }

  return results;
}

/// Extracts hostname from a URL string.
String _extractHostname(String url) {
  try {
    return Uri.parse(url).host;
  } catch (_) {
    return url;
  }
}
