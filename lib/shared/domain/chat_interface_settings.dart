import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_interface_settings.freezed.dart';
part 'chat_interface_settings.g.dart';

/// The multi-model comparison layout (`settings.multiModelDisplayStyle`,
/// `ChatInterfaceSettings.tsx`): `horizontal` (responses side by side, the
/// default), `vertical` (stacked rows) and `single` (one column, switchable).
enum MultiModelDisplayStyle {
  horizontal('horizontal'),
  vertical('vertical'),
  single('single');

  const MultiModelDisplayStyle(this.id);

  /// The original string id persisted in `settings.multiModelDisplayStyle`.
  final String id;

  static MultiModelDisplayStyle fromId(String? id) {
    for (final style in MultiModelDisplayStyle.values) {
      if (style.id == id) return style;
    }
    return MultiModelDisplayStyle.horizontal;
  }
}

/// How the chat background image fills its area (`chatBackground.size`).
enum ChatBackgroundSize {
  cover('cover'),
  contain('contain'),
  auto('auto');

  const ChatBackgroundSize(this.id);

  final String id;

  static ChatBackgroundSize fromId(String? id) {
    for (final v in ChatBackgroundSize.values) {
      if (v.id == id) return v;
    }
    return ChatBackgroundSize.cover;
  }
}

/// Where the chat background image is anchored (`chatBackground.position`).
enum ChatBackgroundPosition {
  center('center'),
  top('top'),
  bottom('bottom'),
  left('left'),
  right('right');

  const ChatBackgroundPosition(this.id);

  final String id;

  static ChatBackgroundPosition fromId(String? id) {
    for (final v in ChatBackgroundPosition.values) {
      if (v.id == id) return v;
    }
    return ChatBackgroundPosition.center;
  }
}

/// How the chat background image tiles (`chatBackground.repeat`).
enum ChatBackgroundRepeat {
  noRepeat('no-repeat'),
  repeat('repeat'),
  repeatX('repeat-x'),
  repeatY('repeat-y');

  const ChatBackgroundRepeat(this.id);

  final String id;

  static ChatBackgroundRepeat fromId(String? id) {
    for (final v in ChatBackgroundRepeat.values) {
      if (v.id == id) return v;
    }
    return ChatBackgroundRepeat.noRepeat;
  }
}

/// The chat background block (`settings.chatBackground`,
/// `ChatInterfaceSettings.tsx`): an optional wallpaper for the message area with
/// opacity, fit, position, tiling and a readability overlay. Defaults mirror the
/// original component fallback.
@freezed
abstract class ChatBackgroundSettings with _$ChatBackgroundSettings {
  const factory ChatBackgroundSettings({
    @Default(false) bool enabled,
    @Default('') String imageUrl,
    @Default(0.7) double opacity,
    @Default(ChatBackgroundSize.cover) ChatBackgroundSize size,
    @Default(ChatBackgroundPosition.center) ChatBackgroundPosition position,
    @Default(ChatBackgroundRepeat.noRepeat) ChatBackgroundRepeat repeat,
    @Default(true) bool showOverlay,
  }) = _ChatBackgroundSettings;

  factory ChatBackgroundSettings.fromJson(Map<String, dynamic> json) =>
      _$ChatBackgroundSettingsFromJson(json);
}

/// The chat-interface configuration the appearance 聊天界面设置 sub-page edits:
/// the multi-model layout, the tool-call / citation / system-prompt-bubble
/// toggles and the chat background block.
///
/// Defaults mirror the original component fallbacks (`ChatInterfaceSettings.tsx`):
/// the three toggles default to on and the multi-model layout to horizontal.
@freezed
abstract class ChatInterfaceSettings with _$ChatInterfaceSettings {
  const factory ChatInterfaceSettings({
    @Default(MultiModelDisplayStyle.horizontal)
    MultiModelDisplayStyle multiModelDisplayStyle,
    @Default(true) bool showToolDetails,
    @Default(true) bool showCitationDetails,
    @Default(true) bool showSystemPromptBubble,
    @Default(ChatBackgroundSettings()) ChatBackgroundSettings background,
  }) = _ChatInterfaceSettings;

  factory ChatInterfaceSettings.fromJson(Map<String, dynamic> json) =>
      _$ChatInterfaceSettingsFromJson(json);
}
