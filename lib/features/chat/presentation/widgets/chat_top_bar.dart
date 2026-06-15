import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';

/// Static UI strings, ported verbatim from the original (i18n is a later
/// effort, per the M4.1 approach).
const String _menuTooltip = '打开侧边栏';
const String _settingsTooltip = '设置';
const String _modelPlaceholderLabel = '未配置模型';

/// The chat top bar, restored to the original Aetherlink default toolbar set
/// (`DEFAULT_TOP_TOOLBAR_SETTINGS`): left = menu (drawer trigger) + topic name,
/// right = model selector ("full" style) + settings.
///
/// This round is appearance-only (M4.2.0b): the menu trigger opens the drawer,
/// but the model selector and settings are unwired, disabled placeholders. No
/// model is configured yet, so the selector shows a disabled "未配置模型"
/// placeholder — never a fabricated model name. The title is provider-driven
/// ([currentTopicProvider]) and stays empty until a topic exists.
class ChatTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const ChatTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicAsync = ref.watch(currentTopicProvider);

    return AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          tooltip: _menuTooltip,
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      // Dynamic title from the application layer; empty until a topic exists.
      title: topicAsync.maybeWhen(
        data: (topic) => topic == null
            ? const SizedBox.shrink()
            : Text(topic.name, overflow: TextOverflow.ellipsis),
        orElse: () => const SizedBox.shrink(),
      ),
      actions: [
        // Model selector ("full" style) — the most recognizable element. No
        // model is configured this round, so it is a disabled "未配置模型"
        // placeholder (no fabricated name, no fake picker).
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.smart_toy_outlined, size: 18),
            label: const Text(_modelPlaceholderLabel),
          ),
        ),
        // Settings — the settings page is a later milestone; disabled.
        const IconButton(
          icon: Icon(Icons.settings),
          tooltip: _settingsTooltip,
          onPressed: null,
        ),
      ],
    );
  }
}
