// 离屏渲染 deck 单页为 PNG（视觉自检闭环）：与编辑器预览共用
// DeckSlideCanvas 的几何模型，无需可见窗口/Overlay——自建
// RenderView + BuildOwner 渲染管线，单帧布局绘制后 toImage。
// 图片元素先解码成 ui.Image 用 RawImage 同步绘制，避免
// Image.memory 异步解码在单帧截图里漏画。

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';

import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/deck_preview.dart';

/// Renders slide [slideIndex]（0 起）of [deck] to PNG bytes at logical
/// [width]px（高度按画布比例推导）.
Future<Uint8List> renderDeckSlidePng(
  DeckDocument deck,
  int slideIndex, {
  double width = 1280,
}) async {
  final slide = deck.slides[slideIndex];
  final height = width * deck.layout.heightInches / deck.layout.widthInches;
  final size = Size(width, height);

  final decoded = <DeckImageElement, ui.Image>{};
  try {
    for (final element in slide.elements) {
      if (element is DeckImageElement && element.isResolved) {
        decoded[element] = await decodeImageFromList(element.bytes);
      }
    }
    final widget = MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.fromSize(
          size: size,
          child: DeckSlideCanvas(
            deck: deck,
            slide: slide,
            showFrame: false,
            imageBuilder: (element) {
              final image = decoded[element];
              return image == null
                  ? const SizedBox.shrink()
                  : RawImage(image: image, fit: BoxFit.fill);
            },
          ),
        ),
      ),
    );
    final image = await _rasterize(widget, size);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('deck 截图 PNG 编码失败');
      }
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    for (final image in decoded.values) {
      image.dispose();
    }
  }
}

Future<ui.Image> _rasterize(Widget widget, Size size) async {
  final boundary = RenderRepaintBoundary();
  final view = ui.PlatformDispatcher.instance.implicitView;
  if (view == null) {
    throw StateError('无可用渲染视图，无法离屏截图');
  }
  final renderView = RenderView(
    view: view,
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      physicalConstraints: BoxConstraints.tight(size),
      devicePixelRatio: 1.0,
    ),
    child: RenderPositionedBox(child: boundary),
  );
  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();

  final buildOwner = BuildOwner(focusManager: FocusManager());
  final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: widget,
  ).attachToRenderTree(buildOwner);
  try {
    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    return boundary.toImage();
  } finally {
    // 卸载离屏树，释放 element/render 资源。
    rootElement.update(
      RenderObjectToWidgetAdapter<RenderBox>(container: boundary),
    );
    buildOwner.finalizeTree();
  }
}
