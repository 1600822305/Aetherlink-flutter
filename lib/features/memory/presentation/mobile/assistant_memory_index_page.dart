import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/assistants_access.dart';
import 'package:aetherlink_flutter/features/memory/application/memory_providers.dart';
import 'package:aetherlink_flutter/features/memory/presentation/mobile/assistant_memory_list_page.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';

/// 按助手查看 (记忆 → 按助手查看) — lists every assistant with its private memory
/// count, sorted by count (assistants that already have memories first). Tapping
/// a row opens that assistant's [AssistantMemoryListPage]. Counts come from the
/// aggregate [assistantMemoryOwnerCountsProvider] (one grouped query, not one
/// per assistant).
class AssistantMemoryIndexPage extends ConsumerWidget {
  const AssistantMemoryIndexPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assistants = ref.watch(assistantsProvider);
    final counts = ref.watch(assistantMemoryOwnerCountsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => context.pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('按助手查看'),
      ),
      body: assistants.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '加载失败：$e',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _empty(theme);
          }
          final countMap = counts.asData?.value ?? const <String, int>{};
          final sorted = [...list]..sort((a, b) {
              final ca = countMap[a.id] ?? 0;
              final cb = countMap[b.id] ?? 0;
              if (ca != cb) return cb.compareTo(ca);
              return a.name.compareTo(b.name);
            });
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _AssistantRow(
              assistant: sorted[i],
              count: countMap[sorted[i].id] ?? 0,
              onTap: () => context.push(
                AssistantMemoryRoute.pathFor(sorted[i].id),
                extra: sorted[i].name,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.users,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 14),
            Text(
              '还没有助手',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '创建助手后即可为其管理私有记忆',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Route helper for an assistant's memory list. Centralised so the home page,
/// the index page and the assistant editor all build the same path.
class AssistantMemoryRoute {
  const AssistantMemoryRoute._();

  static const String pattern = '/settings/memory/assistant/:assistantId';

  static String pathFor(String assistantId) =>
      '/settings/memory/assistant/$assistantId';
}

class _AssistantRow extends StatelessWidget {
  const _AssistantRow({
    required this.assistant,
    required this.count,
    required this.onTap,
  });

  final Assistant assistant;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _glyph(assistant),
                  style: const TextStyle(fontSize: 17),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  assistant.name.trim().isEmpty ? '未命名助手' : assistant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              else
                Text(
                  '暂无',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _glyph(Assistant a) {
    final emoji = a.emoji?.trim();
    if (emoji != null && emoji.isNotEmpty) return emoji;
    final name = a.name.trim();
    return name.isEmpty ? '🤖' : name.substring(0, 1);
  }
}
