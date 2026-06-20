import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Slots laid out by [BubbleFooterLayout].
enum _BubbleSlot { content, footer }

/// Stacks [footer] beneath [content], sizing the box to the content's width
/// (clamped to the incoming min/max width and the footer's minimum width) and
/// then stretching [footer] to that full width.
///
/// This mirrors the original web bubble, where the bottom toolbar is
/// `width: 100%` of a bubble that otherwise shrink-wraps its content: the
/// toolbar fills the bubble so the token chip can sit flush against the far
/// edge. A plain `Column` can't express this — `CrossAxisAlignment.stretch`
/// would blow the bubble out to its max width, while `MainAxisSize.min` leaves
/// the toolbar hugging its own content (token stuck next to the buttons).
class BubbleFooterLayout
    extends SlottedMultiChildRenderObjectWidget<_BubbleSlot, RenderBox> {
  const BubbleFooterLayout({
    required this.content,
    required this.footer,
    super.key,
  });

  final Widget content;
  final Widget footer;

  @override
  Iterable<_BubbleSlot> get slots => _BubbleSlot.values;

  @override
  Widget? childForSlot(_BubbleSlot slot) => switch (slot) {
    _BubbleSlot.content => content,
    _BubbleSlot.footer => footer,
  };

  @override
  _RenderBubbleFooter createRenderObject(BuildContext context) =>
      _RenderBubbleFooter();

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBubbleFooter renderObject,
  ) {
    // No configuration to propagate; layout depends only on the slotted
    // children, which the framework updates separately.
  }
}

class _RenderBubbleFooter extends RenderBox
    with SlottedContainerRenderObjectMixin<_BubbleSlot, RenderBox> {
  RenderBox get _content => childForSlot(_BubbleSlot.content)!;
  RenderBox get _footer => childForSlot(_BubbleSlot.footer)!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    final content = _content;
    final footer = _footer;

    content.layout(
      BoxConstraints(maxWidth: constraints.maxWidth),
      parentUsesSize: true,
    );

    // The footer (toolbar) must not be squeezed below its natural width, so the
    // bubble is at least as wide as the toolbar — matching the web, where the
    // toolbar establishes a floor on the bubble width.
    final footerMinWidth = footer.getMinIntrinsicWidth(double.infinity);
    final width = constraints.constrainWidth(
      math.max(math.max(content.size.width, footerMinWidth), constraints.minWidth),
    );

    footer.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);

    (content.parentData! as BoxParentData).offset = Offset.zero;
    (footer.parentData! as BoxParentData).offset = Offset(
      0,
      content.size.height,
    );

    size = constraints.constrain(
      Size(width, content.size.height + footer.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      final parentData = child.parentData! as BoxParentData;
      context.paintChild(child, offset + parentData.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final parentData = child.parentData! as BoxParentData;
      final hit = result.addWithPaintOffset(
        offset: parentData.offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
