// 跨层访问缝：pptx 工具层（lib/shared/mcp_tools）需要离屏渲染 deck
// 单页截图，而渲染实现在 workspace presentation（复用编辑器预览的
// DeckSlideCanvas）。通过 provider 注入函数引用，保持依赖方向，
// 测试可覆写成假渲染器。

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';

import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/deck_snapshot.dart';

/// Renders slide `slideIndex`（0 起）of `deck` to PNG bytes.
typedef DeckSlideSnapshotRenderer =
    Future<Uint8List> Function(
      DeckDocument deck,
      int slideIndex, {
      double width,
    });

final Provider<DeckSlideSnapshotRenderer> deckSlideSnapshotRendererProvider =
    Provider<DeckSlideSnapshotRenderer>((ref) => renderDeckSlidePng);
