import 'package:aetherlink_perf/aetherlink_perf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/chat_interface_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page/chat_background.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page/chat_body.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_top_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_selection_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/chat_sidebar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar_host.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

/// The chat home page (mobile). After M4.2.0 stood up the real layout shell and
/// proved the presentation → application → repository → Drift pipeline, M4.2.0b
/// restores the visual chrome 1:1 to the original Aetherlink: a full top bar
/// (menu / topic name / model selector / settings), the integrated input with
/// its button toolbar, the sidebar shell, and a themed background surface.
///
/// It remains a pure view: the message list and title come from
/// application-layer providers ([chatMessagesProvider] / [currentTopicProvider],
/// backed by the M1 [ChatRepository]); an empty database yields an empty list
/// rendered as the empty state — no mock data anywhere. It never imports `data`
/// (Rule 1).
///
/// Nothing is wired this round: sending, streaming, message-block rendering, the
/// model selector, the sidebar's real lists, search and the rest are disabled
/// placeholders (later slices), so the tree keeps its final shape.
class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showSystemPromptBubble = ref.watch(
      chatInterfaceSettingsProvider.select((s) => s.showSystemPromptBubble),
    );
    final background = ref.watch(
      chatInterfaceSettingsProvider.select((s) => s.background),
    );
    // Per-assistant wallpaper overrides the global background (web:
    // 助手壁纸优先级高于全局设置).
    final assistantBackground = ref.watch(
      currentAssistantProvider.select((a) => a?.chatBackground),
    );
    final effectiveBackground = resolveChatBackground(
      assistantBackground,
      background,
    );
    final isSelecting = ref.watch(
      messageSelectionProvider.select((s) => s.isSelecting),
    );

    // Tag the performance monitor with the streaming state so jank during a
    // streaming response is attributed correctly. No-op while the monitor is off.
    ref.listen(
      chatControllerProvider.select((s) => s.value?.isStreaming ?? false),
      (_, streaming) => PerfMonitor.instance.setStreaming(streaming),
    );

    // The sidebar is hosted by [SidebarHost] (not `Scaffold.drawer`) so its
    // display style can switch between overlay and push (侧边栏显示方式); the
    // chat page itself stays a plain Scaffold behind it. Buzz when the sidebar
    // opens (gated by the 触觉反馈 master + 侧边栏 toggle), matching the original
    // drawer-open haptic.
    //
    // resizeToAvoidBottomInset is always false: the keyboard offset is handled
    // manually inside [ChatBody] — matching the original's `position: fixed`
    // input — so the Scaffold body never animates its height during the
    // keyboard transition, eliminating the per-frame ShaderMask re-rasterize
    // that caused visible jank.
    return PopScope(
      canPop: !isSelecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isSelecting) {
          ref.read(messageSelectionProvider.notifier).exitSelectionMode();
        }
      },
      child: SidebarHost(
        drawer: const ChatSidebar(),
        onOpened: Haptics.instance.onSidebar,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: isSelecting
              ? const MessageSelectionTopBar()
              : const ChatTopBar(),
          body: ChatBackground(
            background: effectiveBackground,
            child: ChatBody(
              showSystemPromptBubble: showSystemPromptBubble,
              isSelecting: isSelecting,
            ),
          ),
        ),
      ),
    );
  }
}
