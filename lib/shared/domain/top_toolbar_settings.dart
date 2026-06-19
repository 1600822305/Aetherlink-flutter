import 'package:freezed_annotation/freezed_annotation.dart';

part 'top_toolbar_settings.freezed.dart';
part 'top_toolbar_settings.g.dart';

/// The eight configurable chat top-toolbar components (`componentConfig`,
/// `TopToolbarDIYSettings.tsx`), declared in the original panel order so
/// [TopToolbarComponent.values] doubles as the "可用组件" catalog.
///
/// The string [id] is the original's persisted identifier
/// (`topToolbar.componentPositions[].id`).
enum TopToolbarComponent {
  menuButton('menuButton'),
  topicName('topicName'),
  newTopicButton('newTopicButton'),
  clearButton('clearButton'),
  searchButton('searchButton'),
  modelSelector('modelSelector'),
  settingsButton('settingsButton'),
  condenseButton('condenseButton');

  const TopToolbarComponent(this.id);

  /// The original's persisted component id (e.g. `newTopicButton`).
  final String id;
}

/// How the model selector renders inside the DIY layout
/// (`topToolbar.modelSelectorDisplayStyle`): a compact bot [icon] or the
/// model + provider name as [text].
enum ModelSelectorDisplayStyle {
  icon('icon'),
  text('text');

  const ModelSelectorDisplayStyle(this.id);

  final String id;

  static ModelSelectorDisplayStyle fromId(String? id) {
    for (final style in ModelSelectorDisplayStyle.values) {
      if (style.id == id) return style;
    }
    return ModelSelectorDisplayStyle.icon;
  }
}

/// A component placed on the DIY canvas at the free position ([x], [y]) given
/// as percentages of the preview area (`topToolbar.componentPositions[]`).
@freezed
abstract class TopToolbarComponentPosition with _$TopToolbarComponentPosition {
  const factory TopToolbarComponentPosition({
    required TopToolbarComponent component,
    required double x,
    required double y,
  }) = _TopToolbarComponentPosition;

  factory TopToolbarComponentPosition.fromJson(Map<String, dynamic> json) =>
      _$TopToolbarComponentPositionFromJson(json);
}

/// The top-toolbar DIY configuration the appearance 顶部工具栏设置 sub-page edits:
/// the freely-placed component [positions] plus the [modelSelectorDisplayStyle].
///
/// Defaults mirror the original component fallbacks
/// (`TopToolbarDIYSettings.tsx`): no placed components and the icon-mode model
/// selector.
@freezed
abstract class TopToolbarSettings with _$TopToolbarSettings {
  const factory TopToolbarSettings({
    @Default([]) List<TopToolbarComponentPosition> positions,
    @Default(ModelSelectorDisplayStyle.icon)
    ModelSelectorDisplayStyle modelSelectorDisplayStyle,
  }) = _TopToolbarSettings;

  factory TopToolbarSettings.fromJson(Map<String, dynamic> json) =>
      _$TopToolbarSettingsFromJson(json);
}
