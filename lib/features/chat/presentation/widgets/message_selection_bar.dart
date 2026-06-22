import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_export_sheet.dart';

// ---------------------------------------------------------------------------
// Selection top bar: replaces the normal top bar during selection mode.
// Shows: cancel button, selected count, select-all toggle, confirm button.
// ---------------------------------------------------------------------------

class MessageSelectionTopBar extends ConsumerWidget
    implements PreferredSizeWidget {
  const MessageSelectionTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selState = ref.watch(messageSelectionProvider);
    final messages =
        ref.watch(chatControllerProvider).value?.messages ??
        const <ChatMessageView>[];

    return AppBar(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(LucideIcons.x),
        tooltip: '取消',
        onPressed: () =>
            ref.read(messageSelectionProvider.notifier).exitSelectionMode(),
      ),
      title: Text(
        '已选 ${selState.selectedIds.length} 条',
        style: theme.textTheme.titleMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => ref
              .read(messageSelectionProvider.notifier)
              .toggleSelectAll(messages),
          child: Text(
            selState.selectedIds.length >= messages.length ? '取消全选' : '全选',
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(LucideIcons.check, color: cs.primary),
          tooltip: '确认导出',
          onPressed: selState.selectedIds.isEmpty
              ? null
              : () => _confirmExport(context, ref, messages),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _confirmExport(
    BuildContext context,
    WidgetRef ref,
    List<ChatMessageView> messages,
  ) {
    final selState = ref.read(messageSelectionProvider);
    final selectedMessages = messages
        .where((msg) => selState.selectedIds.contains(msg.id))
        .toList();
    if (selectedMessages.isEmpty) return;

    ref.read(messageSelectionProvider.notifier).exitSelectionMode();

    showMessageExportSheet(context, messages: selectedMessages);
  }
}

// ---------------------------------------------------------------------------
// Selection bottom bar: export format buttons + thinking/tool toggles.
// Mirrors Kelivo's ChatSelectionExportBar.
// ---------------------------------------------------------------------------

class MessageSelectionBottomBar extends ConsumerWidget {
  const MessageSelectionBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selState = ref.watch(messageSelectionProvider);
    final messages =
        ref.watch(chatControllerProvider).value?.messages ??
        const <ChatMessageView>[];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Export format buttons row
              Row(
                children: [
                  Expanded(
                    child: _ExportFormatButton(
                      icon: LucideIcons.fileText,
                      label: '纯文本',
                      color: cs.tertiary,
                      onTap: selState.selectedIds.isEmpty
                          ? null
                          : () => _confirmExport(context, ref, messages),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ExportFormatButton(
                      icon: LucideIcons.bookOpenText,
                      label: 'Markdown',
                      color: cs.primary,
                      onTap: selState.selectedIds.isEmpty
                          ? null
                          : () => _confirmExport(context, ref, messages),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ExportFormatButton(
                      icon: LucideIcons.image,
                      label: '图片',
                      color: cs.secondary,
                      onTap: selState.selectedIds.isEmpty
                          ? null
                          : () => _confirmExport(context, ref, messages),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Toggle switches row
              Row(
                children: [
                  Expanded(
                    child: _ToggleChip(
                      icon: LucideIcons.wrench,
                      label: '思考和工具',
                      selected: selState.showThinkingAndTools,
                      onTap: () => ref
                          .read(messageSelectionProvider.notifier)
                          .toggleShowThinkingAndTools(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ToggleChip(
                      icon: LucideIcons.brain,
                      label: '展开思考',
                      selected: selState.expandThinking,
                      enabled: selState.showThinkingAndTools,
                      onTap: () => ref
                          .read(messageSelectionProvider.notifier)
                          .toggleExpandThinking(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmExport(
    BuildContext context,
    WidgetRef ref,
    List<ChatMessageView> messages,
  ) {
    final selState = ref.read(messageSelectionProvider);
    final selectedMessages = messages
        .where((msg) => selState.selectedIds.contains(msg.id))
        .toList();
    if (selectedMessages.isEmpty) return;

    ref.read(messageSelectionProvider.notifier).exitSelectionMode();

    showMessageExportSheet(context, messages: selectedMessages);
  }
}

// ---------------------------------------------------------------------------
// Internal widgets
// ---------------------------------------------------------------------------

class _ExportFormatButton extends StatelessWidget {
  const _ExportFormatButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color.withValues(alpha: isDark ? 0.15 : 0.1);
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = selected
        ? cs.primary.withValues(alpha: isDark ? 0.2 : 0.12)
        : cs.surfaceContainerHighest.withValues(alpha: 0.5);
    final border = selected
        ? cs.primary.withValues(alpha: isDark ? 0.5 : 0.35)
        : cs.outlineVariant.withValues(alpha: 0.2);
    final fg = selected
        ? cs.primary
        : cs.onSurface.withValues(alpha: enabled ? 0.8 : 0.35);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
