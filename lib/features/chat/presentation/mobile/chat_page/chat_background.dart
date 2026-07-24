import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/shared/domain/assistant_chat_background.dart';
import 'package:aetherlink_flutter/shared/domain/chat_interface_settings.dart';

/// The chat-message-area background, ported 1:1 from the original
/// `ChatPageUI.tsx` (lines 805-846). When [ChatBackgroundSettings.enabled] and
/// an image is set it stacks, bottom to top:
///   1. the background image — `opacity` is applied directly to the image layer
///      (`BoxFit`/`Alignment`/`ImageRepeat` mapped from CSS size/position/repeat),
///      blending toward the themed surface painted behind it;
///   2. an optional white readability gradient
///      (`linear-gradient(to bottom, rgba(255,255,255,.3), rgba(255,255,255,.5))`),
///      shown when [ChatBackgroundSettings.showOverlay];
///   3. the chat content ([child]).
/// When disabled (or no image) it collapses to the original solid themed
/// surface. The image is a base64 data URL; it is decoded once and cached as a
/// [MemoryImage] so rebuilds (typing, streaming) never re-decode it.

/// Resolves the wallpaper to render: the current assistant's [chatBackground]
/// wins when it is enabled with an image (web: 助手壁纸优先级高于全局设置),
/// otherwise the [global] chat-interface background is used. The assistant's
/// optional fields fall back to the same defaults as the global block.
ChatBackgroundSettings resolveChatBackground(
  AssistantChatBackground? assistant,
  ChatBackgroundSettings global,
) {
  if (assistant != null && assistant.enabled && assistant.imageUrl.isNotEmpty) {
    return ChatBackgroundSettings(
      enabled: true,
      imageUrl: assistant.imageUrl,
      opacity: assistant.opacity ?? 0.7,
      size: ChatBackgroundSize.fromId(assistant.size),
      position: ChatBackgroundPosition.fromId(assistant.position),
      repeat: ChatBackgroundRepeat.fromId(assistant.repeat),
      showOverlay: assistant.showOverlay ?? true,
    );
  }
  return global;
}

class ChatBackground extends StatefulWidget {
  const ChatBackground({
    super.key,
    required this.background,
    required this.child,
  });

  final ChatBackgroundSettings background;
  final Widget child;

  @override
  State<ChatBackground> createState() => _ChatBackgroundState();
}

class _ChatBackgroundState extends State<ChatBackground> {
  MemoryImage? _image;
  String _decodedUrl = '';

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  @override
  void didUpdateWidget(ChatBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.background.imageUrl != _decodedUrl) {
      _decodeImage();
    }
  }

  /// Decodes the `data:<mime>;base64,<...>` URL into cached bytes. Mirrors the
  /// settings page's `_ImageArea._decode`.
  void _decodeImage() {
    final url = widget.background.imageUrl;
    _decodedUrl = url;
    final marker = url.indexOf('base64,');
    if (marker < 0) {
      _image = null;
      return;
    }
    try {
      _image = MemoryImage(base64Decode(url.substring(marker + 7)));
    } on FormatException {
      _image = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = widget.background;
    final image = _image;

    if (!background.enabled || image == null) {
      return ColoredBox(color: theme.colorScheme.surface, child: widget.child);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              image: DecorationImage(
                image: image,
                fit: _fitFor(background.size),
                alignment: _alignmentFor(background.position),
                repeat: _repeatFor(background.repeat),
                opacity: background.opacity.clamp(0.0, 1.0),
              ),
            ),
          ),
        ),
        if (background.showOverlay)
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x4DFFFFFF), Color(0x80FFFFFF)],
                  ),
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

/// CSS `background-size` → [BoxFit] (`auto` keeps the natural size, like CSS).
BoxFit _fitFor(ChatBackgroundSize size) => switch (size) {
  ChatBackgroundSize.cover => BoxFit.cover,
  ChatBackgroundSize.contain => BoxFit.contain,
  ChatBackgroundSize.auto => BoxFit.none,
};

/// CSS `background-position` → [Alignment].
Alignment _alignmentFor(ChatBackgroundPosition position) => switch (position) {
  ChatBackgroundPosition.center => Alignment.center,
  ChatBackgroundPosition.top => Alignment.topCenter,
  ChatBackgroundPosition.bottom => Alignment.bottomCenter,
  ChatBackgroundPosition.left => Alignment.centerLeft,
  ChatBackgroundPosition.right => Alignment.centerRight,
};

/// CSS `background-repeat` → [ImageRepeat].
ImageRepeat _repeatFor(ChatBackgroundRepeat repeat) => switch (repeat) {
  ChatBackgroundRepeat.noRepeat => ImageRepeat.noRepeat,
  ChatBackgroundRepeat.repeat => ImageRepeat.repeat,
  ChatBackgroundRepeat.repeatX => ImageRepeat.repeatX,
  ChatBackgroundRepeat.repeatY => ImageRepeat.repeatY,
};
