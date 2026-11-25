import 'dart:async';

import 'package:flutter/cupertino.dart'
    show cupertinoTextSelectionHandleControls;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm3/src/core/buffer/cell_offset.dart';
import 'package:xterm3/src/terminal.dart';
import 'package:xterm3/src/terminal_view.dart';
import 'package:xterm3/src/ui/controller.dart';

/// Mobile-style selection overlay for [TerminalView]: platform-native teardrop
/// handles at both ends of the active selection, draggable to adjust the
/// range, plus a compact copy/select-all toolbar floating above the selection.
///
/// Lives inside the package so it can use [RenderTerminal]'s cell↔pixel
/// mapping directly instead of re-deriving it from outside. Handles use raw
/// pointer events rather than gesture recognizers so that horizontal drags
/// are never contested by an enclosing [PageView]-style horizontal pan
/// recognizer (there is no arena to lose).
class TerminalSelectionOverlay extends StatefulWidget {
  const TerminalSelectionOverlay({
    super.key,
    required this.terminalView,
    required this.controller,
    required this.scrollController,
    required this.child,
  });

  final TerminalViewState terminalView;
  final TerminalController controller;
  final ScrollController scrollController;
  final Widget child;

  @override
  State<TerminalSelectionOverlay> createState() =>
      _TerminalSelectionOverlayState();
}

class _TerminalSelectionOverlayState extends State<TerminalSelectionOverlay> {
  static const _hitPad = 12.0;

  final _stackKey = GlobalKey();
  final _toolbar = OverlayPortalController();
  bool _dragging = false;
  CellOffset? _dragFixed;
  Offset? _dragTip;

  Terminal get _terminal => widget.terminalView.widget.terminal;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    widget.scrollController.addListener(_sync);
    _terminal.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant TerminalSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_sync);
      widget.scrollController.addListener(_sync);
    }
    if (oldWidget.terminalView.widget.terminal != _terminal) {
      oldWidget.terminalView.widget.terminal.removeListener(_sync);
      _terminal.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    widget.scrollController.removeListener(_sync);
    _terminal.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    if (widget.controller.selection == null && _toolbar.isShowing) {
      _toolbar.hide();
    }
    setState(() {});
  }

  RenderBox? get _stackBox {
    final box = _stackKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box : null;
  }

  double get _lineHeight {
    try {
      return widget.terminalView.renderTerminal.cellSize.height;
    } catch (_) {
      return 16;
    }
  }

  /// Top-left corner of [cell] in this overlay's coordinate space.
  Offset? _cellToLocal(CellOffset cell) {
    final stack = _stackBox;
    if (stack == null) return null;
    try {
      final render = widget.terminalView.renderTerminal;
      if (!render.attached || !render.hasSize) return null;
      return stack.globalToLocal(render.localToGlobal(render.getOffset(cell)));
    } catch (_) {
      return null;
    }
  }

  CellOffset? _globalToCell(Offset global) {
    try {
      final render = widget.terminalView.renderTerminal;
      if (!render.attached || !render.hasSize) return null;
      return render.getCellOffset(render.globalToLocal(global));
    } catch (_) {
      return null;
    }
  }

  TextSelectionControls get _controls {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return cupertinoTextSelectionHandleControls;
      default:
        return materialTextSelectionHandleControls;
    }
  }

  void _copy() {
    final range = widget.controller.selection;
    _toolbar.hide();
    if (range == null) return;
    final text = _terminal.buffer.getText(range);
    widget.controller.clearSelection();
    unawaited(Clipboard.setData(ClipboardData(text: text)));
  }

  void _selectAll() {
    final buffer = _terminal.buffer;
    widget.controller.setSelection(
      buffer.createAnchor(0, 0),
      buffer.createAnchor(_terminal.viewWidth, buffer.height - 1),
    );
  }

  void _endDrag() {
    if (!_dragging) return;
    _dragging = false;
    _dragFixed = null;
    _dragTip = null;
    if (widget.controller.selection != null) _toolbar.show();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.controller.selection?.normalized;
    final h = _lineHeight;
    final begin = range == null ? null : _cellToLocal(range.begin);
    final end = range == null ? null : _cellToLocal(range.end);
    // Handle tips point at the bottom-left of the first selected cell and the
    // bottom-left of the (exclusive) end cell, i.e. the selection edges.
    final startPt = begin == null ? null : begin + Offset(0, h);
    final endPt = end == null ? null : end + Offset(0, h);
    return OverlayPortal(
      controller: _toolbar,
      overlayChildBuilder: (context) => _buildToolbar(context, startPt, endPt),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          bool visible(Offset? p) =>
              p != null && p.dy > 0 && p.dy <= size.height + 0.5;
          return Stack(
            key: _stackKey,
            clipBehavior: Clip.hardEdge,
            children: [
              widget.child,
              if (range != null && visible(startPt))
                _handle(startPt!, TextSelectionHandleType.left, range.end),
              if (range != null && visible(endPt))
                _handle(endPt!, TextSelectionHandleType.right, range.begin),
            ],
          );
        },
      ),
    );
  }

  Widget _handle(Offset tip, TextSelectionHandleType type, CellOffset fixed) {
    final controls = _controls;
    final h = _lineHeight;
    final size = controls.getHandleSize(h);
    final anchor = controls.getHandleAnchor(type, h);
    return Positioned(
      left: tip.dx - anchor.dx - _hitPad,
      top: tip.dy - anchor.dy - _hitPad,
      width: size.width + _hitPad * 2,
      height: size.height + _hitPad * 2,
      // 手柄用原始指针事件：拖动量必须无条件跟手。进竞技场会被外层翻页
      // 抢走并触发 cancel，拖动直接死掉；防翻页由 app 侧的物理锁负责。
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          _dragging = true;
          _dragFixed = fixed;
          _dragTip = tip;
          _toolbar.hide();
          setState(() {});
        },
        onPointerMove: (e) {
          if (!_dragging) return;
          final t = (_dragTip ?? tip) + e.delta;
          _dragTip = t;
          // The tip sits half a line below the row it edits: map the point
          // half a line above the tip back into cell space.
          final cell = _globalToCell(
            (_stackBox?.localToGlobal(t) ?? Offset.zero) - Offset(0, h / 2),
          );
          final f = _dragFixed;
          if (cell == null || f == null) return;
          final buffer = _terminal.buffer;
          widget.controller.setSelection(
            buffer.createAnchor(f.x, f.y),
            buffer.createAnchor(cell.x, cell.y),
          );
        },
        onPointerUp: (_) => _endDrag(),
        onPointerCancel: (_) => _endDrag(),
        child: Padding(
          padding: const EdgeInsets.all(_hitPad),
          child: controls.buildHandle(context, type, h),
        ),
      ),
    );
  }

  /// Copy/select-all pill floating above the selection start, flipped below
  /// when there is no room. Anchors are global because the toolbar renders in
  /// the root overlay.
  Widget _buildToolbar(BuildContext context, Offset? startPt, Offset? endPt) {
    final stack = _stackBox;
    if (_dragging ||
        stack == null ||
        widget.controller.selection == null ||
        !TickerMode.valuesOf(context).enabled) {
      return const SizedBox.shrink();
    }
    final size = stack.size;
    final h = _lineHeight;
    final singleLine =
        startPt != null && endPt != null && (endPt.dy - startPt.dy).abs() < 1;
    final x = singleLine ? (startPt.dx + endPt.dx) / 2 : size.width / 2;
    final topY = ((startPt?.dy ?? 0) - h).clamp(0.0, size.height);
    final bottomY =
        ((endPt?.dy ?? size.height) + _controls.getHandleSize(h).height)
            .clamp(0.0, size.height);
    return TextSelectionToolbar(
      anchorAbove: stack.localToGlobal(Offset(x, topY)),
      anchorBelow: stack.localToGlobal(Offset(x, bottomY)),
      children: [
        TextSelectionToolbarTextButton(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onPressed: _copy,
          child: const Text('复制'),
        ),
        TextSelectionToolbarTextButton(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onPressed: _selectAll,
          child: const Text('全选'),
        ),
      ],
    );
  }
}
