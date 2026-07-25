import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/shared/utils/provider_icons.dart';

class MultiModelEntry extends ConsumerWidget {
  const MultiModelEntry({
    super.key,
    required this.messageId,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final String messageId;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  static const _processing = <MessageStatus>{
    MessageStatus.pending,
    MessageStatus.processing,
    MessageStatus.searching,
    MessageStatus.streaming,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final view = ref.watch(
      chatControllerProvider.select((a) => a.messageById(messageId)),
    );
    final name = view?.modelName ?? '模型';
    final isProcessing = _processing.contains(view?.status);
    final logo = _ModelLogo(
      modelId: view?.modelId,
      providerId: view?.providerId,
      name: name,
      size: 20,
    );

    final Widget child;
    if (expanded) {
      child = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 28,
        padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? null
              : Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            logo,
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      child = Tooltip(
        message: name,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(1),
          child: logo,
        ),
      );
    }

    return Opacity(
      opacity: isProcessing ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(expanded ? 14 : 13),
        child: child,
      ),
    );
  }
}

/// A round provider/model logo with a first-letter fallback, sized [size].
class _ModelLogo extends StatelessWidget {
  const _ModelLogo({
    required this.modelId,
    required this.providerId,
    required this.name,
    required this.size,
  });

  final String? modelId;
  final String? providerId;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
        style: theme.textTheme.labelSmall,
      ),
    );
    if (modelId == null && providerId == null) {
      return ClipOval(child: fallback);
    }
    final asset = getModelOrProviderIcon(
      modelId ?? '',
      providerId ?? '',
      isDark: isDark,
    );
    return ClipOval(
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
