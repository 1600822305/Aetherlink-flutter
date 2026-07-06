import 'package:freezed_annotation/freezed_annotation.dart';

part 'selection_menu_settings.freezed.dart';
part 'selection_menu_settings.g.dart';

/// 复制面板（长按选中文本弹出的选择菜单）可用操作的 id。展示信息（图标/文案）
/// 与执行逻辑在 presentation 层的面板组件里注册，这里只保存持久化用的 id。
const String kSelectionMenuCopy = 'copy';
const String kSelectionMenuSelectAll = 'selectAll';
const String kSelectionMenuQuote = 'quote';
const String kSelectionMenuShare = 'share';

/// 预设启用的复制面板操作（顺序即展示顺序）：复制 / 全选 / 引用到输入框 / 分享。
/// [SelectionMenuSettings.enabledItemIds] 为 null 时用此预设。
const List<String> kDefaultSelectionMenuItemIds = [
  kSelectionMenuCopy,
  kSelectionMenuSelectAll,
  kSelectionMenuQuote,
  kSelectionMenuShare,
];

/// 复制面板配置：外观设置 → 界面定制 → 复制面板 页编辑，消息选中文本的
/// 自定义选择菜单读取。
///
/// [useCustomMenu] 关闭时回退到系统自带的选择菜单（含第三方 Process Text 项，
/// 如「问AI」）；开启时使用应用内自定义面板，[enabledItemIds] 控制显示哪些
/// 操作及顺序（null 表示用预设 [kDefaultSelectionMenuItemIds]）。
@freezed
abstract class SelectionMenuSettings with _$SelectionMenuSettings {
  const factory SelectionMenuSettings({
    @Default(true) bool useCustomMenu,
    List<String>? enabledItemIds,
  }) = _SelectionMenuSettings;

  factory SelectionMenuSettings.fromJson(Map<String, dynamic> json) =>
      _$SelectionMenuSettingsFromJson(json);
}
