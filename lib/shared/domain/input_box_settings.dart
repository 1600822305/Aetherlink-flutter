import 'package:freezed_annotation/freezed_annotation.dart';

part 'input_box_settings.freezed.dart';

/// The three input-box visual presets (`settings.inputBoxStyle`,
/// `useInputStyles.ts`): `default` (8px radius, regular shadow), `modern`
/// (12px radius, heavier shadow + glass blur) and `minimal` (6px radius,
/// fainter border, no shadow).
enum InputBoxStyle {
  defaultStyle('default'),
  modern('modern'),
  minimal('minimal');

  const InputBoxStyle(this.id);

  /// The original string id persisted in `settings.inputBoxStyle`.
  final String id;

  static InputBoxStyle fromId(String? id) {
    for (final style in InputBoxStyle.values) {
      if (style.id == id) return style;
    }
    return InputBoxStyle.defaultStyle;
  }
}

/// Every configurable toolbar button (`AVAILABLE_BUTTONS`,
/// `InputBoxSettings.tsx`), declared in the original list order so
/// [InputBoxButtonId.values] doubles as the "available buttons" catalog.
///
/// The string [id] is the original's persisted identifier
/// (`integratedInputLeftButtons` / `integratedInputRightButtons`).
enum InputBoxButtonId {
  tools('tools'),
  mcpTools('mcp-tools'),
  clear('clear'),
  image('image'),
  video('video'),
  knowledge('knowledge'),
  search('search'),
  upload('upload'),
  camera('camera'),
  photoSelect('photo-select'),
  fileUpload('file-upload'),
  aiDebate('ai-debate'),
  quickPhrase('quick-phrase'),
  multiModel('multi-model'),
  send('send'),
  voice('voice');

  const InputBoxButtonId(this.id);

  /// The original's persisted button id (e.g. `mcp-tools`).
  final String id;
}

/// The input-box configuration the appearance sub-page edits and the chat
/// composer consumes: the visual [style] plus the left / right toolbar button
/// layout.
///
/// Defaults mirror the original component fallbacks (`InputBoxSettings.tsx`):
/// left `tools / clear / search`, right `upload / voice / send`. Buttons not in
/// either list are the "available" (hidden) pool.
@freezed
abstract class InputBoxSettings with _$InputBoxSettings {
  const factory InputBoxSettings({
    @Default(InputBoxStyle.defaultStyle) InputBoxStyle style,
    @Default([
      InputBoxButtonId.tools,
      InputBoxButtonId.clear,
      InputBoxButtonId.search,
    ])
    List<InputBoxButtonId> leftButtons,
    @Default([
      InputBoxButtonId.upload,
      InputBoxButtonId.voice,
      InputBoxButtonId.send,
    ])
    List<InputBoxButtonId> rightButtons,
  }) = _InputBoxSettings;
}
