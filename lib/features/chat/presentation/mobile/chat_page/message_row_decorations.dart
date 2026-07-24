import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_nav_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';

/// Flashes a translucent primary tint over the message a navigation jump
/// landed on (web scrollToMessage's highlight), fading back out when
/// [navHighlightMessageIdProvider] clears after 1.6s. Watches with a select
/// on its own id, so only the affected row rebuilds.
class NavFlashHighlight extends ConsumerWidget {
  const NavFlashHighlight({
    super.key,
    required this.messageId,
    required this.child,
  });

  final String messageId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      navHighlightMessageIdProvider.select((id) => id == messageId),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      color: active
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      child: child,
    );
  }
}

/// Keeps a message row's element tree alive when it scrolls out of the
/// viewport cache, mirroring the web's resident DOM. Rebuilding a long
/// markdown bubble from scratch takes 100ms+ on a single frame (the dominant
/// jank source measured on-device); keeping it alive makes re-entry free.
class KeepAliveItem extends StatefulWidget {
  const KeepAliveItem({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveItem> createState() => _KeepAliveItemState();
}

class _KeepAliveItemState extends State<KeepAliveItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// A message row with a leading checkbox, shown during multi-select mode.
class SelectableMessageRow extends ConsumerWidget {
  const SelectableMessageRow({
    super.key,
    required this.messageId,
    required this.selected,
    required this.child,
  });

  final String messageId;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          ref.read(messageSelectionProvider.notifier).toggleMessage(messageId),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                key: ValueKey(selected),
                size: 22,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
          Expanded(child: IgnorePointer(child: child)),
        ],
      ),
    );
  }
}
