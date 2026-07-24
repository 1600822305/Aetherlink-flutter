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
