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
  reasoningEffort('reasoning-effort'),
  send('send'),
  voice('voice');

  const InputBoxButtonId(this.id);

  /// The original's persisted button id (e.g. `mcp-tools`).
  final String id;

  /// Resolves a persisted [id] back to its button, or `null` when the token is
  /// unknown (a forward-compatible no-op so a stale stored id is dropped rather
  /// than throwing).
  static InputBoxButtonId? fromId(String id) {
    for (final button in InputBoxButtonId.values) {
      if (button.id == id) return button;
    }
    return null;
  }
}

/// Every dispatchable input-box behavior — the single registry the toolbar
/// buttons, the two aggregator menus and the appearance preview all route
/// through, so each action's behavior/state lives in one place instead of the
/// original's three independent copies (`ButtonToolbar` / `ToolsMenu` /
/// `UploadMenu`, where the same action is redeclared in each).
///
/// It is a superset of the toolbar buttons: [toolsMenu] / [uploadMenu] are the
/// two aggregator buttons that open menus; the middle group is shared by the
/// toolbar and the menus; and [newTopic] / [note] are menu-only — they are not
/// toolbar-configurable, so they have no [InputBoxButtonId].
enum InputBoxAction {
  toolsMenu,
  uploadMenu,
  mcpTools,
  newTopic,
  clearTopic,
  generateImage,
  generateVideo,
  knowledge,
  webSearch,
  photoSelect,
  camera,
  fileUpload,
  note,
  aiDebate,
  quickPhrase,
  multiModel,
  reasoningEffort,
  voice,
}

/// The action a configurable toolbar [id] dispatches, or `null` for
/// [InputBoxButtonId.send] (intrinsic to the composer, not routed through the
/// behavior port).
InputBoxAction? inputBoxButtonAction(InputBoxButtonId id) => switch (id) {
  InputBoxButtonId.tools => InputBoxAction.toolsMenu,
  InputBoxButtonId.mcpTools => InputBoxAction.mcpTools,
  InputBoxButtonId.clear => InputBoxAction.clearTopic,
  InputBoxButtonId.image => InputBoxAction.generateImage,
  InputBoxButtonId.video => InputBoxAction.generateVideo,
  InputBoxButtonId.knowledge => InputBoxAction.knowledge,
  InputBoxButtonId.search => InputBoxAction.webSearch,
  InputBoxButtonId.upload => InputBoxAction.uploadMenu,
  InputBoxButtonId.camera => InputBoxAction.camera,
  InputBoxButtonId.photoSelect => InputBoxAction.photoSelect,
  InputBoxButtonId.fileUpload => InputBoxAction.fileUpload,
  InputBoxButtonId.aiDebate => InputBoxAction.aiDebate,
  InputBoxButtonId.quickPhrase => InputBoxAction.quickPhrase,
  InputBoxButtonId.multiModel => InputBoxAction.multiModel,
  InputBoxButtonId.reasoningEffort => InputBoxAction.reasoningEffort,
  InputBoxButtonId.voice => InputBoxAction.voice,
  InputBoxButtonId.send => null,
};

/// The two aggregator menus opened from the toolbar: 扩展 ([tools]) and 更多
/// ([upload]).
enum InputBoxMenu { tools, upload }

/// The 扩展 menu's items, in the original `ToolsMenu.tsx` default order
/// (`toolbarButtons.order`).
const List<InputBoxAction> kToolsMenuActions = [
  InputBoxAction.mcpTools,
  InputBoxAction.newTopic,
  InputBoxAction.clearTopic,
  InputBoxAction.generateImage,
  InputBoxAction.generateVideo,
  InputBoxAction.knowledge,
  InputBoxAction.webSearch,
];

/// The 更多 menu's items, in the original `UploadMenu.tsx` order (core
/// upload items first, then the optional sections).
const List<InputBoxAction> kUploadMenuActions = [
  InputBoxAction.photoSelect,
  InputBoxAction.camera,
  InputBoxAction.fileUpload,
  InputBoxAction.note,
  InputBoxAction.aiDebate,
  InputBoxAction.quickPhrase,
  InputBoxAction.multiModel,
];

/// The ordered item list rendered inside [menu].
List<InputBoxAction> inputBoxMenuActions(InputBoxMenu menu) => switch (menu) {
  InputBoxMenu.tools => kToolsMenuActions,
  InputBoxMenu.upload => kUploadMenuActions,
};

/// Whether [action] is one of the three mutually-exclusive session modes
/// (网络搜索 / 图像生成 / 视频生成) whose icon dims when the mode is off — the port of
/// `useExclusiveMode`'s `ExclusiveMode`.
bool isInputBoxModeAction(InputBoxAction action) =>
    action == InputBoxAction.webSearch ||
    action == InputBoxAction.generateImage ||
    action == InputBoxAction.generateVideo;

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
