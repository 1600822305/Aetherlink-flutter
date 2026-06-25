import 'package:freezed_annotation/freezed_annotation.dart';

part 'thinking_settings.freezed.dart';
part 'thinking_settings.g.dart';

/// 思考过程显示样式 (`settings.thinkingDisplayStyle`, `ThinkingBlock.tsx`).
///
/// Ported display styles for the thinking block. `timeline` is the new default
/// (RikkaHub-inspired chain-of-thought with interleaved reasoning/tool nodes);
/// the original web styles (`compact` / `full` / `minimal` / `bubble` / `card` /
/// `hidden`) are preserved for users who prefer them.
enum ThinkingDisplayStyle {
  timeline('timeline'),
  compact('compact'),
  full('full'),
  minimal('minimal'),
  bubble('bubble'),
  card('card'),
  hidden('hidden');

  const ThinkingDisplayStyle(this.id);

  /// The original string id persisted in `settings.thinkingDisplayStyle`.
  final String id;

  static ThinkingDisplayStyle fromId(String? id) {
    for (final v in ThinkingDisplayStyle.values) {
      if (v.id == id) return v;
    }
    // Unknown / a not-yet-ported original style falls back to the default.
    return ThinkingDisplayStyle.timeline;
  }
}

/// The 思考过程设置 configuration the appearance sub-page edits and the chat
/// thinking block renders, a port of the original `settings` slice fields read
/// by `ThinkingProcessSettings.tsx` / `ThinkingBlock.tsx`.
///
/// Defaults mirror the original component fallbacks: compact display style,
/// auto-collapse on, tool-inline on.
@freezed
abstract class ThinkingSettings with _$ThinkingSettings {
  const factory ThinkingSettings({
    @Default(ThinkingDisplayStyle.timeline) ThinkingDisplayStyle displayStyle,
    // 思考完成后自动折叠，原版默认开。
    @Default(true) bool thoughtAutoCollapse,
    // 思考过程内显示工具调用，原版默认开（Flutter 暂未接入，仅持久化）。
    @Default(true) bool thinkingToolInline,
  }) = _ThinkingSettings;

  factory ThinkingSettings.fromJson(Map<String, dynamic> json) =>
      _$ThinkingSettingsFromJson(json);
}
