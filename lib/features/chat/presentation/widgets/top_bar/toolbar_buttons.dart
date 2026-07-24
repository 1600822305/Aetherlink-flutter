import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/top_toolbar_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/top_toolbar_component_catalog.dart';

const String clearTooltip = '清空内容';

const String _modelPlaceholderLabel = '未配置模型';

const Color clearConfirmColor = Color(0xFFF44336);

/// A toolbar icon button mirroring the original's `IconButton` (a `null`
/// handler renders the glyph but does not act — its behavior is a later slice).
class ToolbarIconButton extends StatelessWidget {
  const ToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: icon, tooltip: tooltip, onPressed: onPressed);
  }
}

/// 清空内容 button — a port of the original `handleClearTopicWithConfirm`: the
/// first tap arms a confirm state (red 警告三角 glyph) that auto-resets after 3s;
/// the second tap clears the current topic's messages ([Topics.clearMessages]).
class ClearTopicButton extends ConsumerStatefulWidget {
  const ClearTopicButton({super.key});

  @override
  ConsumerState<ClearTopicButton> createState() => _ClearTopicButtonState();
}

class _ClearTopicButtonState extends ConsumerState<ClearTopicButton> {
  bool _confirm = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _onPressed() {
    final topicId = ref.read(currentTopicProvider).value?.id;
    if (topicId == null) return;
    if (_confirm) {
      _resetTimer?.cancel();
      ref.read(topicsProvider.notifier).clearMessages(topicId);
      setState(() => _confirm = false);
    } else {
      setState(() => _confirm = true);
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _confirm = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ToolbarIconButton(
      icon: _confirm
          ? const Icon(
              LucideIcons.alertTriangle,
              size: 20,
              color: clearConfirmColor,
            )
          : topToolbarComponentIcon(
              TopToolbarComponent.clearButton,
              color: theme.colorScheme.onSurface,
            ),
      tooltip: clearTooltip,
      onPressed: _onPressed,
    );
  }
}

/// The model selector, a 1:1 port of `UnifiedModelDisplay`: `icon` ⇒ a small
/// `Bot` `IconButton`; `text` ⇒ an outlined button stacking the model name
/// (`body2`/500) over the provider name (`caption`). Shows the placeholder, not
/// a fabricated name, when no model is configured.
class ModelSelector extends StatelessWidget {
  const ModelSelector({
    super.key,
    required this.style,
    required this.current,
    required this.onPressed,
    this.comboName,
  });

  final ModelSelectorDisplayStyle style;
  final CurrentModel? current;
  final VoidCallback onPressed;
  final String? comboName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelLabel =
        comboName ?? current?.model.name ?? _modelPlaceholderLabel;

    if (style == ModelSelectorDisplayStyle.icon) {
      return ToolbarIconButton(
        icon: topToolbarComponentIcon(
          TopToolbarComponent.modelSelector,
          color: theme.colorScheme.onSurface,
        ),
        tooltip: modelLabel,
        onPressed: onPressed,
      );
    }

    final providerName = comboName != null
        ? '模型组合'
        : (current?.provider.name ?? '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          side: BorderSide(color: theme.dividerColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: Size.zero,
          visualDensity: VisualDensity.compact,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                modelLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (providerName.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.4,
                    height: 1.0,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
