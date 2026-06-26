// The monospace text area with a left line-number gutter and font-size zoom.
//
// Layout: a fixed gutter (line numbers, vertically synced to the field) + a
// horizontally scrollable, non-wrapping TextField, so each logical line maps to
// exactly one gutter row. Zoom changes the font size (8–32, default 13) rather
// than transforming the canvas — an InteractiveViewer would fight the field's
// caret/selection. Pinch is handled by a raw Listener (never joins the gesture
// arena, so single-finger scroll / select / tap on the field keep working).

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const double kEditorMinFontSize = 8;
const double kEditorMaxFontSize = 32;
const double kEditorDefaultFontSize = 13;

const double _lineHeightFactor = 1.5;
const double _topPad = 12;
const double _bottomPad = 24;
const double _textLeftPad = 12;
const double _textRightPad = 16;

class EditorTextArea extends StatefulWidget {
  const EditorTextArea({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.editing,
    required this.fontSize,
    required this.onFontSize,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool editing;
  final double fontSize;
  final ValueChanged<double> onFontSize;

  @override
  State<EditorTextArea> createState() => _EditorTextAreaState();
}

class _EditorTextAreaState extends State<EditorTextArea> {
  final _textScroll = ScrollController();
  final _gutterScroll = ScrollController();
  final _hScroll = ScrollController();

  final Map<int, Offset> _pointers = {};
  double? _pinchStartGap;
  double _pinchStartFont = kEditorDefaultFontSize;

  @override
  void initState() {
    super.initState();
    _textScroll.addListener(_syncGutter);
  }

  @override
  void dispose() {
    _textScroll.removeListener(_syncGutter);
    _textScroll.dispose();
    _gutterScroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  void _syncGutter() {
    if (!_gutterScroll.hasClients) return;
    final target = _textScroll.offset.clamp(
      _gutterScroll.position.minScrollExtent,
      _gutterScroll.position.maxScrollExtent,
    );
    if ((_gutterScroll.offset - target).abs() > 0.01) {
      _gutterScroll.jumpTo(target);
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      final pts = _pointers.values.toList();
      _pinchStartGap = (pts[0] - pts[1]).distance;
      _pinchStartFont = widget.fontSize;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final gap0 = _pinchStartGap;
    if (_pointers.length >= 2 && gap0 != null && gap0 > 0) {
      final pts = _pointers.values.toList();
      final gap = (pts[0] - pts[1]).distance;
      final next = (_pinchStartFont * gap / gap0)
          .clamp(kEditorMinFontSize, kEditorMaxFontSize)
          .toDouble();
      if (next != widget.fontSize) widget.onFontSize(next);
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStartGap = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.controller.text;
    final lineCount = '\n'.allMatches(text).length + 1;
    final lineHeight = widget.fontSize * _lineHeightFactor;

    final textStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: widget.fontSize,
      height: _lineHeightFactor,
      color: theme.colorScheme.onSurface,
    );
    final gutterStyle = textStyle.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LineNumberGutter(
                controller: _gutterScroll,
                lineCount: lineCount,
                lineHeight: lineHeight,
                style: gutterStyle,
                borderColor: theme.dividerColor,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final width = _contentWidth(text, textStyle, c.maxWidth);
                    return SingleChildScrollView(
                      controller: _hScroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        child: TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          scrollController: _textScroll,
                          readOnly: !widget.editing,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          keyboardType: TextInputType.multiline,
                          style: textStyle,
                          cursorColor: theme.colorScheme.primary,
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.fromLTRB(
                              _textLeftPad,
                              _topPad,
                              _textRightPad,
                              _bottomPad,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: _ZoomPill(
              fontSize: widget.fontSize,
              onChange: widget.onFontSize,
            ),
          ),
        ],
      ),
    );
  }

  // Width of the longest line so the field never wraps and can pan horizontally.
  static double _contentWidth(String text, TextStyle style, double viewport) {
    var maxLen = 1;
    for (final line in text.split('\n')) {
      if (line.length > maxLen) maxLen = line.length;
    }
    final tp = TextPainter(
      text: TextSpan(text: 'M' * maxLen, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = tp.width + _textLeftPad + _textRightPad;
    return width < viewport ? viewport : width;
  }
}

class _LineNumberGutter extends StatelessWidget {
  const _LineNumberGutter({
    required this.controller,
    required this.lineCount,
    required this.lineHeight,
    required this.style,
    required this.borderColor,
  });

  final ScrollController controller;
  final int lineCount;
  final double lineHeight;
  final TextStyle style;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final digits = lineCount.toString().length;
    final tp = TextPainter(
      text: TextSpan(text: '0' * digits, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = tp.width + 18;

    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: SingleChildScrollView(
        controller: controller,
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(
            top: _topPad,
            bottom: _bottomPad,
            right: 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 1; i <= lineCount; i++)
                SizedBox(
                  height: lineHeight,
                  child: Text('$i', style: style, maxLines: 1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomPill extends StatelessWidget {
  const _ZoomPill({required this.fontSize, required this.onChange});

  final double fontSize;
  final ValueChanged<double> onChange;

  void _bump(double delta) => onChange(
    (fontSize + delta).clamp(kEditorMinFontSize, kEditorMaxFontSize),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      elevation: 2,
      shape: StadiumBorder(side: BorderSide(color: theme.dividerColor)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillButton(
            icon: LucideIcons.minus,
            onTap: fontSize > kEditorMinFontSize ? () => _bump(-1) : null,
          ),
          InkWell(
            onTap: () => onChange(kEditorDefaultFontSize),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text(
                '${fontSize.round()}',
                style: theme.textTheme.labelMedium,
              ),
            ),
          ),
          _PillButton(
            icon: LucideIcons.plus,
            onTap: fontSize < kEditorMaxFontSize ? () => _bump(1) : null,
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null
              ? theme.disabledColor
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
