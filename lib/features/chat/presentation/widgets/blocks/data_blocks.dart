import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';

Widget _card(BuildContext context, {required Widget child}) {
  final theme = Theme.of(context);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: theme.dividerColor),
    ),
    child: child,
  );
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Renders a `TOOL` block, mirroring `ToolBlock.tsx`: a collapsible card with
/// the tool name, a status chip and (when expanded) the arguments and result.
class ToolBlockView extends StatefulWidget {
  const ToolBlockView({required this.block, super.key});

  final ToolBlock block;

  @override
  State<ToolBlockView> createState() => _ToolBlockViewState();
}

class _ToolBlockViewState extends State<ToolBlockView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = widget.block;
    final name = block.toolName ?? block.toolId;
    final args = block.arguments;
    final content = block.content;
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(
                  LucideIcons.wrench,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  block.status.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(
                  _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            if (args != null && args.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('参数', style: theme.textTheme.labelSmall),
              SelectableText(
                args.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: 8),
              Text('结果', style: theme.textTheme.labelSmall),
              SelectableText(
                content.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Renders a `CITATION` block, mirroring `CitationBlock.tsx`: the citation text
/// plus a numbered list of sources (web search / generic), each opening its URL.
class CitationBlockView extends StatelessWidget {
  const CitationBlockView({required this.block, super.key});

  final CitationBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <({String title, String? url})>[
      for (final s in block.webSearch ?? const []) (title: s.title, url: s.url),
      for (final s in block.sources ?? const [])
        (title: s.title ?? s.url ?? '', url: s.url),
    ];

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.quote,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '引用来源',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (block.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            AppMarkdown(content: block.content),
          ],
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: (entries[i].url ?? '').isEmpty
                    ? null
                    : () => _openUrl(entries[i].url!),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entries[i].title.isEmpty
                            ? (entries[i].url ?? '')
                            : entries[i].title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Renders a `CHART` block. Chart rendering needs a charting dependency (later
/// slice); for now this shows a placeholder card labelled with the chart type.
class ChartBlockView extends StatelessWidget {
  const ChartBlockView({required this.block, super.key});

  final ChartBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _card(
      context,
      child: Row(
        children: [
          Icon(
            LucideIcons.chartColumn,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '图表（${block.chartType.name}）· 即将支持',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a legacy `KNOWLEDGE_REFERENCE` block, mirroring
/// `KnowledgeReferenceBlock.tsx`: the reference content with its source and
/// similarity score.
class KnowledgeReferenceBlockView extends StatelessWidget {
  const KnowledgeReferenceBlockView({required this.block, super.key});

  final KnowledgeReferenceBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = block.source;
    final similarity = block.similarity;
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.bookOpen,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '知识库引用',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (similarity != null)
                Text(
                  '相似度 ${(similarity * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AppMarkdown(content: block.content),
          if (source != null && source.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '来源：$source',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
