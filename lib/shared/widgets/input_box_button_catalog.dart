import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';

/// Visual catalog for the configurable input-box toolbar buttons, shared by the
/// chat composer (the live toolbar) and the appearance 输入框管理设置 page (the
/// drag-and-drop list).
///
/// Two icon contexts are kept because the original deliberately renders a few
/// buttons differently in each place:
///   * the settings list (`AVAILABLE_BUTTONS`, `InputBoxSettings.tsx`) shows
///     each button in its brand color — and `image` uses a `Camera` glyph,
///     `search` uses lucide `Search`;
///   * the live toolbar (`ButtonToolbar.tsx`) tints most glyphs with the
///     on-surface color — and `image` uses an `Image` glyph, `search` uses the
///     bespoke star-search `CustomIcon`.
///
/// Per ADR-0009 the lucide originals map to `LucideIcons.*`; the four non-lucide
/// originals (`tools`/settingsPanel, `search`, `ai-debate`, `quick-phrase`) are
/// ported as SVG assets from `src/components/icons/iconData.ts`.

/// The original's non-lucide `CustomIcon` glyphs, ported as SVG assets.
const String kSettingsPanelIcon = 'assets/icons/aether_settings_panel.svg';
const String kSearchIcon = 'assets/icons/aether_search.svg';
const String kAiDebateIcon = 'assets/icons/aether_ai_debate.svg';
const String kQuickPhraseIcon = 'assets/icons/aether_quick_phrase.svg';

/// Settings-list metadata for one button (`AVAILABLE_BUTTONS`): its drag-list
/// [label], [description] and brand [color]. A `null` [color] mirrors the
/// original's `'currentColor'` (rendered in the on-surface text color).
class InputBoxButtonInfo {
  const InputBoxButtonInfo({
    required this.label,
    required this.description,
    required this.color,
  });

  final String label;
  final String description;
  final Color? color;
}

/// The original's brand palette for the settings list (`AVAILABLE_BUTTONS`).
const Color _green = Color(0xFF4CAF50);
const Color _purple = Color(0xFF9C27B0);
const Color _pink = Color(0xFFE91E63);
const Color _emerald = Color(0xFF059669);
const Color _blue = Color(0xFF3B82F6);
const Color _amber = Color(0xFFF59E0B);
const Color _indigo = Color(0xFF1976D2);
const Color _sky = Color(0xFF2196F3);
const Color _orange = Color(0xFFFF9800);
const Color _red = kInputBoxClearConfirmColor;

/// The 清空内容 confirm-armed accent (`#f44336`, MUI `error.main`): the red of the
/// `AlertTriangle` glyph / 确认清空 label / active tint shown after the first tap,
/// shared by the standalone toolbar button and the 扩展 menu row.
const Color kInputBoxClearConfirmColor = Color(0xFFF44336);

InputBoxButtonInfo inputBoxButtonInfo(InputBoxButtonId id) => switch (id) {
  InputBoxButtonId.tools => const InputBoxButtonInfo(
    label: '扩展',
    description: '启用/禁用扩展功能',
    color: _green,
  ),
  InputBoxButtonId.mcpTools => const InputBoxButtonInfo(
    label: '工具',
    description: '启用/禁用MCP工具功能',
    color: _green,
  ),
  InputBoxButtonId.clear => const InputBoxButtonInfo(
    label: '清空内容',
    description: '清空当前话题内容',
    color: null,
  ),
  InputBoxButtonId.image => const InputBoxButtonInfo(
    label: '生成图片',
    description: '切换图片生成模式',
    color: _purple,
  ),
  InputBoxButtonId.video => const InputBoxButtonInfo(
    label: '生成视频',
    description: '切换视频生成模式',
    color: _pink,
  ),
  InputBoxButtonId.knowledge => const InputBoxButtonInfo(
    label: '知识库',
    description: '访问知识库功能',
    color: _emerald,
  ),
  InputBoxButtonId.search => const InputBoxButtonInfo(
    label: '网络搜索',
    description: '启用网络搜索功能',
    color: _blue,
  ),
  InputBoxButtonId.upload => const InputBoxButtonInfo(
    label: '添加内容',
    description: '添加图片、文件或使用其他功能',
    color: _amber,
  ),
  InputBoxButtonId.camera => const InputBoxButtonInfo(
    label: '拍摄照片',
    description: '使用相机拍摄照片',
    color: _purple,
  ),
  InputBoxButtonId.photoSelect => const InputBoxButtonInfo(
    label: '选择图片',
    description: '从相册选择图片',
    color: _indigo,
  ),
  InputBoxButtonId.fileUpload => const InputBoxButtonInfo(
    label: '上传文件',
    description: '上传文档或其他文件',
    color: _green,
  ),
  InputBoxButtonId.aiDebate => const InputBoxButtonInfo(
    label: 'AI辩论',
    description: '开始多AI角色辩论',
    color: _sky,
  ),
  InputBoxButtonId.quickPhrase => const InputBoxButtonInfo(
    label: '快捷短语',
    description: '插入预设的文本短语',
    color: _purple,
  ),
  InputBoxButtonId.multiModel => const InputBoxButtonInfo(
    label: '多模型发送',
    description: '同时向多个AI模型发送消息',
    color: null,
  ),
  InputBoxButtonId.send => const InputBoxButtonInfo(
    label: '发送按钮',
    description: '发送消息按钮',
    color: null,
  ),
  InputBoxButtonId.voice => const InputBoxButtonInfo(
    label: '语音按钮',
    description: '语音输入按钮',
    color: null,
  ),
};

/// The settings-list glyph (`AVAILABLE_BUTTONS` icons), tinted [color].
///
/// Differs from [inputBoxToolbarIcon] for `image` (Camera here) and `search`
/// (lucide Search here), matching the original.
Widget inputBoxListIcon(
  InputBoxButtonId id, {
  required Color color,
  double size = 18,
}) => switch (id) {
  InputBoxButtonId.tools => _svg(kSettingsPanelIcon, color, size),
  InputBoxButtonId.mcpTools => Icon(
    LucideIcons.wrench,
    size: size,
    color: color,
  ),
  InputBoxButtonId.clear => Icon(LucideIcons.trash2, size: size, color: color),
  InputBoxButtonId.image => Icon(LucideIcons.camera, size: size, color: color),
  InputBoxButtonId.video => Icon(LucideIcons.video, size: size, color: color),
  InputBoxButtonId.knowledge => Icon(
    LucideIcons.bookOpen,
    size: size,
    color: color,
  ),
  InputBoxButtonId.search => Icon(LucideIcons.search, size: size, color: color),
  InputBoxButtonId.upload => Icon(LucideIcons.plus, size: size, color: color),
  InputBoxButtonId.camera => Icon(LucideIcons.camera, size: size, color: color),
  InputBoxButtonId.photoSelect => Icon(
    LucideIcons.image,
    size: size,
    color: color,
  ),
  InputBoxButtonId.fileUpload => Icon(
    LucideIcons.fileText,
    size: size,
    color: color,
  ),
  InputBoxButtonId.aiDebate => _svg(kAiDebateIcon, color, size),
  InputBoxButtonId.quickPhrase => _svg(kQuickPhraseIcon, color, size),
  InputBoxButtonId.multiModel => Icon(
    LucideIcons.arrowLeftRight,
    size: size,
    color: color,
  ),
  InputBoxButtonId.send => Icon(LucideIcons.send, size: size, color: color),
  InputBoxButtonId.voice => Icon(LucideIcons.mic, size: size, color: color),
};

/// The live-toolbar glyph (`buttonConfigs` icons, `ButtonToolbar.tsx`), tinted
/// [color]. `send` / `voice` are rendered by the composer itself because their
/// glyph and color swap with run-time state.
/// When [active] the 清空内容 button shows its confirm-armed `AlertTriangle`
/// instead of `Trash2` (`ButtonToolbar`'s `clearConfirmMode`).
Widget inputBoxToolbarIcon(
  InputBoxButtonId id, {
  required Color color,
  double size = 20,
  bool active = false,
}) => switch (id) {
  InputBoxButtonId.tools => _svg(kSettingsPanelIcon, color, size),
  InputBoxButtonId.mcpTools => Icon(
    LucideIcons.wrench,
    size: size,
    color: color,
  ),
  InputBoxButtonId.clear => Icon(
    active ? LucideIcons.alertTriangle : LucideIcons.trash2,
    size: size,
    color: color,
  ),
  InputBoxButtonId.image => Icon(LucideIcons.image, size: size, color: color),
  InputBoxButtonId.video => Icon(LucideIcons.video, size: size, color: color),
  InputBoxButtonId.knowledge => Icon(
    LucideIcons.bookOpen,
    size: size,
    color: color,
  ),
  InputBoxButtonId.search => _svg(kSearchIcon, color, size),
  InputBoxButtonId.upload => Icon(LucideIcons.plus, size: size, color: color),
  InputBoxButtonId.camera => Icon(LucideIcons.camera, size: size, color: color),
  InputBoxButtonId.photoSelect => Icon(
    LucideIcons.image,
    size: size,
    color: color,
  ),
  InputBoxButtonId.fileUpload => Icon(
    LucideIcons.fileText,
    size: size,
    color: color,
  ),
  InputBoxButtonId.aiDebate => _svg(kAiDebateIcon, color, size),
  InputBoxButtonId.quickPhrase => _svg(kQuickPhraseIcon, color, size),
  InputBoxButtonId.multiModel => Icon(
    LucideIcons.arrowLeftRight,
    size: size,
    color: color,
  ),
  InputBoxButtonId.send => Icon(LucideIcons.send, size: size, color: color),
  InputBoxButtonId.voice => Icon(LucideIcons.mic, size: size, color: color),
};

/// The live-toolbar resting color for [id]: `camera` / `photo-select` /
/// `file-upload` keep their fixed brand color even at rest (`ButtonToolbar.tsx`);
/// every other button uses the on-surface [iconColor].
Color inputBoxToolbarRestColor(InputBoxButtonId id, Color iconColor) =>
    switch (id) {
      InputBoxButtonId.camera => _purple,
      InputBoxButtonId.photoSelect => _indigo,
      InputBoxButtonId.fileUpload => _green,
      _ => iconColor,
    };

/// The live-toolbar active accent for [id] (`buttonConfigs` active `color`):
/// 网络搜索 blue / 图像生成 purple / 视频生成 · 语音 red / 工具 green. Only used when the
/// button is active; every other button falls back to [fallback] (its resting
/// color), so this is a no-op for buttons that never light up.
Color inputBoxToolbarActiveColor(InputBoxButtonId id, Color fallback) =>
    switch (id) {
      InputBoxButtonId.search => _blue,
      InputBoxButtonId.image => _purple,
      InputBoxButtonId.video => _red,
      InputBoxButtonId.voice => _red,
      InputBoxButtonId.mcpTools => _green,
      InputBoxButtonId.clear => _red,
      _ => fallback,
    };

/// The live-toolbar tooltip for [id] (`buttonConfigs` `tooltip`). The three
/// session modes flip to an "exit mode" label while [active] (`ButtonToolbar`'s
/// `imageGenerationMode ? '退出图像生成模式' : '图像生成'`).
String inputBoxToolbarTooltip(InputBoxButtonId id, {bool active = false}) =>
    switch (id) {
      InputBoxButtonId.tools => '扩展',
      InputBoxButtonId.mcpTools => 'MCP工具',
      InputBoxButtonId.clear => active ? '确认清空' : '清空内容',
      InputBoxButtonId.image => active ? '退出图像生成模式' : '图像生成',
      InputBoxButtonId.video => active ? '退出视频生成模式' : '视频生成',
      InputBoxButtonId.knowledge => '知识库',
      InputBoxButtonId.search => active ? '退出网络搜索模式' : '网络搜索',
      InputBoxButtonId.upload => '添加内容',
      InputBoxButtonId.camera => '拍摄照片',
      InputBoxButtonId.photoSelect => '选择图片',
      InputBoxButtonId.fileUpload => '上传文件',
      InputBoxButtonId.aiDebate => '开始AI辩论',
      InputBoxButtonId.quickPhrase => '快捷短语',
      InputBoxButtonId.multiModel => '多模型发送',
      InputBoxButtonId.send => '发送消息',
      InputBoxButtonId.voice => '切换到语音输入模式',
    };

/// Visual metadata for one aggregator-menu row (`ToolsMenu` / `UploadMenu`
/// `ListItemText` + `ListItemIcon`): the brand [color] (a `null` color mirrors
/// the original's `currentColor`, rendered in the on-surface text color), the
/// [label] and an optional [subtitle] (`secondary`). [dimWhenInactive] flags the
/// three session modes, whose icon renders at 60% opacity while the mode is off
/// (the original's `alpha(color, 0.6)`).
class InputBoxMenuItemInfo {
  const InputBoxMenuItemInfo({
    required this.label,
    this.subtitle,
    this.color,
    this.dimWhenInactive = false,
  });

  final String label;
  final String? subtitle;
  final Color? color;
  final bool dimWhenInactive;
}

/// The title shown above [menu]'s items (the aggregator button's label).
String inputBoxMenuTitle(InputBoxMenu menu) => switch (menu) {
  InputBoxMenu.tools => '扩展',
  InputBoxMenu.upload => '添加内容',
};

/// Per-item metadata for the two aggregator menus, ported 1:1 from the original
/// `ToolsMenu.tsx` / `UploadMenu.tsx` item configs (labels / secondary text /
/// icon colors). [toolsMenu] / [uploadMenu] never appear inside a menu, so they
/// fall back to a neutral entry.
InputBoxMenuItemInfo inputBoxMenuItemInfo(InputBoxAction action) =>
    switch (action) {
      InputBoxAction.mcpTools => const InputBoxMenuItemInfo(
        label: '工具',
        color: _green,
        dimWhenInactive: true,
      ),
      InputBoxAction.newTopic => const InputBoxMenuItemInfo(
        label: '新建话题',
        color: _green,
      ),
      InputBoxAction.clearTopic => const InputBoxMenuItemInfo(
        label: '清空内容',
        color: _blue,
      ),
      InputBoxAction.generateImage => const InputBoxMenuItemInfo(
        label: '生成图片',
        color: _purple,
        dimWhenInactive: true,
      ),
      InputBoxAction.generateVideo => const InputBoxMenuItemInfo(
        label: '生成视频',
        color: _red,
        dimWhenInactive: true,
      ),
      InputBoxAction.knowledge => const InputBoxMenuItemInfo(
        label: '知识库',
        color: _sky,
      ),
      InputBoxAction.webSearch => const InputBoxMenuItemInfo(
        label: '网络搜索',
        color: _blue,
        dimWhenInactive: true,
      ),
      InputBoxAction.photoSelect => const InputBoxMenuItemInfo(
        label: '从相册选择图片',
        color: _indigo,
      ),
      InputBoxAction.camera => const InputBoxMenuItemInfo(
        label: '拍摄照片',
        color: _purple,
      ),
      InputBoxAction.fileUpload => const InputBoxMenuItemInfo(
        label: '上传文件',
        color: _green,
      ),
      InputBoxAction.note => const InputBoxMenuItemInfo(
        label: '添加笔记',
        subtitle: '从笔记中选择内容发送',
        color: _orange,
      ),
      InputBoxAction.aiDebate => const InputBoxMenuItemInfo(
        label: '开始AI辩论',
        subtitle: '多AI角色辩论功能',
      ),
      InputBoxAction.quickPhrase => const InputBoxMenuItemInfo(
        label: '快捷短语',
        subtitle: '插入预设的文本短语',
      ),
      InputBoxAction.multiModel => const InputBoxMenuItemInfo(
        label: '发送到多个模型',
        subtitle: '同时向多个AI模型发送消息',
      ),
      InputBoxAction.toolsMenu => const InputBoxMenuItemInfo(label: '扩展'),
      InputBoxAction.uploadMenu => const InputBoxMenuItemInfo(label: '添加内容'),
      InputBoxAction.voice => const InputBoxMenuItemInfo(label: '语音输入'),
    };

/// The aggregator-menu glyph for [action], tinted [color] at [size]
/// (`ToolsMenu` / `UploadMenu` `ListItemIcon` icons). The mode items reuse the
/// composer's toolbar glyphs (`search` SVG, `image`/`video` lucide) for parity.
/// When [active] the 清空内容 row shows its confirm-armed `AlertTriangle`
/// instead of `Trash2` (`ToolsMenu`'s `clearConfirmMode`).
Widget inputBoxMenuIcon(
  InputBoxAction action, {
  required Color color,
  double size = 20,
  bool active = false,
}) => switch (action) {
  InputBoxAction.mcpTools => Icon(LucideIcons.wrench, size: size, color: color),
  InputBoxAction.newTopic => Icon(LucideIcons.plus, size: size, color: color),
  InputBoxAction.clearTopic => Icon(
    active ? LucideIcons.alertTriangle : LucideIcons.trash2,
    size: size,
    color: color,
  ),
  InputBoxAction.generateImage => Icon(
    LucideIcons.image,
    size: size,
    color: color,
  ),
  InputBoxAction.generateVideo => Icon(
    LucideIcons.video,
    size: size,
    color: color,
  ),
  InputBoxAction.knowledge => Icon(
    LucideIcons.bookOpen,
    size: size,
    color: color,
  ),
  InputBoxAction.webSearch => _svg(kSearchIcon, color, size),
  InputBoxAction.photoSelect => Icon(
    LucideIcons.image,
    size: size,
    color: color,
  ),
  InputBoxAction.camera => Icon(LucideIcons.camera, size: size, color: color),
  InputBoxAction.fileUpload => Icon(
    LucideIcons.fileText,
    size: size,
    color: color,
  ),
  InputBoxAction.note => Icon(LucideIcons.bookOpen, size: size, color: color),
  InputBoxAction.aiDebate => _svg(kAiDebateIcon, color, size),
  InputBoxAction.quickPhrase => _svg(kQuickPhraseIcon, color, size),
  InputBoxAction.multiModel => Icon(
    LucideIcons.arrowLeftRight,
    size: size,
    color: color,
  ),
  InputBoxAction.toolsMenu => _svg(kSettingsPanelIcon, color, size),
  InputBoxAction.uploadMenu => Icon(LucideIcons.plus, size: size, color: color),
  InputBoxAction.voice => Icon(LucideIcons.mic, size: size, color: color),
};

/// Renders a bespoke (non-lucide) SVG glyph tinted to [color], matching the
/// original `CustomIcon` fill behavior.
Widget _svg(String asset, Color color, double size) => SvgPicture.asset(
  asset,
  width: size,
  height: size,
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
);
