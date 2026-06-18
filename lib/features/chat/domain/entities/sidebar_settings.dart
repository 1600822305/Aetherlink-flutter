import 'package:freezed_annotation/freezed_annotation.dart';

part 'sidebar_settings.freezed.dart';
part 'sidebar_settings.g.dart';

/// 消息样式 (`settings.messageStyle`, `useSettingsManagement.ts`): `bubble` 气泡
/// 样式（默认）；`plain` 简洁样式。
enum MessageStyle {
  plain('plain', '简洁'),
  bubble('bubble', '气泡');

  const MessageStyle(this.id, this.label);

  /// The original string id persisted in `settings.messageStyle`.
  final String id;

  /// The 设置 tab dropdown label (`messageStyleOptions`).
  final String label;

  static MessageStyle fromId(String? id) {
    for (final v in MessageStyle.values) {
      if (v.id == id) return v;
    }
    return MessageStyle.bubble;
  }
}

/// 对话导航 (`settings.messageNavigation`): `none` 不显示（默认）；`buttons` 显示上下
/// 按钮快速跳转。
enum MessageNavigation {
  none('none', '不显示'),
  buttons('buttons', '上下按钮');

  const MessageNavigation(this.id, this.label);

  /// The original string id persisted in `settings.messageNavigation`.
  final String id;

  /// The 设置 tab dropdown label (`messageNavigationOptions`).
  final String label;

  static MessageNavigation fromId(String? id) {
    for (final v in MessageNavigation.values) {
      if (v.id == id) return v;
    }
    return MessageNavigation.none;
  }
}

/// The 设置 tab (侧边栏快捷设置面板) configuration the sidebar edits, a port of the
/// fields read by `SettingsTab/index.tsx` + its sub-sections.
///
/// Persisted as a single JSON blob (the Flutter equivalent of the web's
/// `localStorage` `appSettings` + `settings` Redux slice). Defaults mirror the
/// web seeds (`useSettingsStorage` `DEFAULT_SETTINGS` + the `settings` slice
/// `defaults.ts`).
///
/// Scope split (confirmed with the product owner):
///   * 常规设置 7 项 + 侧边栏宽度 are fully wired (see [SidebarSettingsController]
///     consumers); `showMessageDivider` / `copyableCodeBlocks` already drive the
///     chat view, the rest persist and light up as their chat widgets land.
///   * 上下文 / 输入 / 代码块行为 / 数学 (单美元) persist here but are 即将支持 — the
///     subsystems consuming them are later slices.
///   * 性能节流 / 虚拟化列表 / 代码编辑器主题 / 数学引擎下拉 are Web-only framework tax
///     and are intentionally dropped.
@freezed
abstract class SidebarSettings with _$SidebarSettings {
  const factory SidebarSettings({
    // ── 常规设置 (7 项) ──────────────────────────────────────────────────────
    @Default(true) bool showMessageDivider,
    @Default(true) bool copyableCodeBlocks,
    @Default(true) bool renderUserInputAsMarkdown,
    @Default(true) bool autoScrollToBottom,
    @Default(MessageStyle.bubble) MessageStyle messageStyle,
    @Default(MessageNavigation.none) MessageNavigation messageNavigation,
    @Default(true) bool showContextTokenIndicator,
    // ── 侧边栏宽度 (px) ───────────────────────────────────────────────────────
    // Flutter mobile drawer default 350 (`AppSidebar.solid.tsx`); clamped to
    // [kSidebarWidthMin, getSafeMaxSidebarWidth] when applied.
    @Default(350.0) double sidebarWidth,
    // ── 上下文设置 (即将支持) ─────────────────────────────────────────────────
    @Default(100000) int contextWindowSize,
    @Default(20) int contextCount,
    @Default(8192) int maxOutputTokens,
    @Default(true) bool enableMaxOutputTokens,
    // ── 输入设置 (即将支持) ───────────────────────────────────────────────────
    @Default(false) bool pasteLongTextAsFile,
    @Default(1500) int pasteLongTextThreshold,
    // ── 代码块设置 (即将支持) ─────────────────────────────────────────────────
    @Default(true) bool codeShowLineNumbers,
    @Default(true) bool codeCollapsible,
    @Default(true) bool codeWrappable,
    @Default(false) bool codeDefaultCollapsed,
    @Default(true) bool mermaidEnabled,
    // ── 数学公式设置 ─────────────────────────────────────────────────────────
    // Single-dollar inline math; the engine dropdown (KaTeX/MathJax) is dropped
    // because Flutter renders natively with flutter_math_fork.
    @Default(true) bool mathEnableSingleDollar,
  }) = _SidebarSettings;

  factory SidebarSettings.fromJson(Map<String, dynamic> json) =>
      _$SidebarSettingsFromJson(json);
}
