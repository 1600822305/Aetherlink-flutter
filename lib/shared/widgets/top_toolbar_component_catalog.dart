import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/domain/top_toolbar_settings.dart';

/// Visual catalog for the chat top-toolbar DIY components, shared by the
/// appearance 顶部工具栏设置 page's "可用组件" grid and its live layout preview.
///
/// Per ADR-0009 the lucide originals map to `LucideIcons.*`; the non-lucide
/// `CustomIcon` glyphs (`menuButton`/documentPanel, `searchButton`/search,
/// `condenseButton`/foldVertical) are ported as SVG assets from
/// `src/components/icons/iconData.ts`.

/// The original's non-lucide `CustomIcon` glyphs, ported as SVG assets.
const String kDocumentPanelIcon = 'assets/icons/aether_document_panel.svg';
const String kSearchIcon = 'assets/icons/aether_search.svg';
const String kFoldVerticalIcon = 'assets/icons/aether_fold_vertical.svg';

/// The component's display name in the panel / layout (`componentConfig.name`,
/// `topToolbarDIY.components.*`).
String topToolbarComponentName(TopToolbarComponent component) =>
    switch (component) {
      TopToolbarComponent.menuButton => '菜单按钮',
      TopToolbarComponent.topicName => '话题名称',
      TopToolbarComponent.newTopicButton => '新建话题',
      TopToolbarComponent.clearButton => '清空按钮',
      TopToolbarComponent.searchButton => '搜索按钮',
      TopToolbarComponent.modelSelector => '模型选择器',
      TopToolbarComponent.settingsButton => '设置按钮',
      TopToolbarComponent.condenseButton => '压缩上下文',
    };

/// The component's glyph (`componentConfig.icon`), tinted [color]. `topicName`
/// and the text-mode `modelSelector` render their own widgets in the preview,
/// so the icon here is only what the panel card and the icon-mode preview show.
Widget topToolbarComponentIcon(
  TopToolbarComponent component, {
  required Color color,
  double size = 20,
}) => switch (component) {
  TopToolbarComponent.menuButton => _svg(kDocumentPanelIcon, color, size),
  TopToolbarComponent.topicName => Icon(
    LucideIcons.messageSquare,
    size: size,
    color: color,
  ),
  TopToolbarComponent.newTopicButton => Icon(
    LucideIcons.messageSquarePlus,
    size: size,
    color: color,
  ),
  TopToolbarComponent.clearButton => Icon(
    LucideIcons.trash2,
    size: size,
    color: color,
  ),
  TopToolbarComponent.searchButton => _svg(kSearchIcon, color, size),
  TopToolbarComponent.modelSelector => Icon(
    LucideIcons.bot,
    size: size,
    color: color,
  ),
  TopToolbarComponent.settingsButton => Icon(
    LucideIcons.settings,
    size: size,
    color: color,
  ),
  TopToolbarComponent.condenseButton => _svg(kFoldVerticalIcon, color, size),
};

/// Renders a bespoke (non-lucide) SVG glyph tinted to [color], matching the
/// original `CustomIcon` behavior.
Widget _svg(String asset, Color color, double size) => SvgPicture.asset(
  asset,
  width: size,
  height: size,
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
);
