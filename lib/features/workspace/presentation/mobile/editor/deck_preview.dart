// 编辑器内的 PPT deck 源预览（*.deck.json）。用 aetherlink_pptx 的
// DeckDocument 模型按幻灯片几何（英寸坐标）原生渲染缩放画布，与
// PPTX 导出共用同一份源，所见即所得；解析失败时展示可读的错误提示。

import 'package:flutter/material.dart';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Whether [name] is a deck source file the editor can preview.
bool isDeckSourceFileName(String name) =>
    name.toLowerCase().endsWith('.deck.json');

/// Read-only slide rendering of the deck source [content]（编辑器预览态）。
class DeckPreview extends StatelessWidget {
  const DeckPreview({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final DeckDocument deck;
    try {
      deck = DeckDocument.parse(content);
    } on DeckParseException catch (e) {
      return _ParseError(message: e.message);
    }
    final issues = runDeckQa(deck);
    final errorCount = issues
        .where((i) => i.severity == DeckQaSeverity.error)
        .length;
    final warnCount = issues.length - errorCount;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (issues.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _QaBanner(errorCount: errorCount, warnCount: warnCount),
          ),
        for (final (index, slide) in deck.slides.indexed) ...[
          _SlideCanvas(deck: deck, slide: slide),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              '${index + 1} / ${deck.slides.length}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

class _ParseError extends StatelessWidget {
  const _ParseError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.fileWarning, size: 32),
            const SizedBox(height: 12),
            Text('deck 源无法解析', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _QaBanner extends StatelessWidget {
  const _QaBanner({required this.errorCount, required this.warnCount});

  final int errorCount;
  final int warnCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasErrors = errorCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasErrors
            ? scheme.errorContainer
            : scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            hasErrors ? LucideIcons.circleAlert : LucideIcons.info,
            size: 16,
            color: hasErrors ? scheme.onErrorContainer : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '布局 QA：$errorCount 个错误，$warnCount 个警告',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hasErrors ? scheme.onErrorContainer : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One slide rendered at its 16:9（或 4:3）比例，内部用英寸→逻辑像素的
/// 统一 scale 定位元素（与 pptx_writer / HTML 渲染同一几何模型）。
class _SlideCanvas extends StatelessWidget {
  const _SlideCanvas({required this.deck, required this.slide});

  final DeckDocument deck;
  final DeckSlide slide;

  @override
  Widget build(BuildContext context) {
    final ratio = deck.layout.widthInches / deck.layout.heightInches;
    return AspectRatio(
      aspectRatio: ratio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / deck.layout.widthInches;
          return Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: _color(slide.background) ?? Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
            child: Stack(
              children: [
                for (final element in slide.elements)
                  Positioned(
                    left: element.frame.x * scale,
                    top: element.frame.y * scale,
                    width: element.frame.w * scale,
                    height: element.frame.h * scale <= 0
                        ? 1
                        : element.frame.h * scale,
                    child: _elementWidget(element, scale),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _elementWidget(DeckElement element, double scale) {
    return switch (element) {
      DeckTextElement() => _TextBox(element: element, scale: scale),
      DeckShapeElement() => _Shape(element: element, scale: scale),
      DeckImageElement() => Image.memory(element.bytes, fit: BoxFit.fill),
      DeckTableElement() => _DeckTable(element: element, scale: scale),
    };
  }
}

Color? _color(DeckColor? c, {int transparency = 0}) {
  if (c == null) return null;
  final rgb = int.parse(c.hex, radix: 16);
  final alpha = ((100 - transparency) * 255 / 100).round().clamp(0, 255);
  return Color((alpha << 24) | rgb);
}

/// 1 英寸 = 72pt；字号 pt → 逻辑像素按画布 scale（px/inch）换算。
double _fontPx(double sizePt, double scale) => sizePt / 72 * scale;

TextStyle _runStyle(DeckTextRun run, double scale, {Color? fallback}) {
  return TextStyle(
    fontSize: _fontPx(run.size ?? 18, scale),
    fontWeight: run.bold ? FontWeight.bold : FontWeight.normal,
    fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
    color: _color(run.color) ?? fallback ?? Colors.black87,
    fontFamily: run.font,
    height: 1.2,
  );
}

TextAlign _textAlign(String? align) => switch (align) {
  'center' => TextAlign.center,
  'right' => TextAlign.right,
  _ => TextAlign.left,
};

class _TextBox extends StatelessWidget {
  const _TextBox({required this.element, required this.scale});

  final DeckTextElement element;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (final para in element.paragraphs)
        Padding(
          padding: EdgeInsets.only(left: para.indentLevel * 0.25 * scale),
          child: Text.rich(
            TextSpan(
              children: [
                if (para.bullet)
                  TextSpan(
                    text: '• ',
                    style: _runStyle(
                      para.runs.isEmpty
                          ? const DeckTextRun(text: '')
                          : para.runs.first,
                      scale,
                    ),
                  ),
                for (final run in para.runs)
                  TextSpan(text: run.text, style: _runStyle(run, scale)),
              ],
            ),
            textAlign: _textAlign(para.align),
            softWrap: true,
          ),
        ),
    ];
    // 正文按源几何可能比容器略高（真实 PPT 也会溢出，QA 另行报告）；
    // 预览用不可滚动的 scroll view 承载再裁剪，避免 RenderFlex 溢出报错。
    return Container(
      color: _color(element.fill),
      alignment: switch (element.valign) {
        'middle' => Alignment.centerLeft,
        'bottom' => Alignment.bottomLeft,
        _ => Alignment.topLeft,
      },
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _Shape extends StatelessWidget {
  const _Shape({required this.element, required this.scale});

  final DeckShapeElement element;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final fill = _color(element.fill, transparency: element.fillTransparency);
    final borderColor = _color(element.lineColor);
    final borderWidth = element.lineWidth == null
        ? 0.0
        : _fontPx(element.lineWidth!, scale);
    if (element.kind == DeckShapeKind.line) {
      return Center(
        child: Container(
          height: (borderWidth > 0 ? borderWidth : 1).clamp(1, 100).toDouble(),
          color: borderColor ?? fill ?? Colors.black54,
        ),
      );
    }
    final shortSide =
        (element.frame.w < element.frame.h
            ? element.frame.w
            : element.frame.h) *
        scale;
    return Container(
      decoration: BoxDecoration(
        color: fill,
        shape: element.kind == DeckShapeKind.ellipse
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: element.kind == DeckShapeKind.roundRect
            ? BorderRadius.circular((element.radius ?? 0.15) * shortSide)
            : null,
        border: borderColor != null && borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
      ),
    );
  }
}

class _DeckTable extends StatelessWidget {
  const _DeckTable({required this.element, required this.scale});

  final DeckTableElement element;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final borderColor = _color(element.borderColor) ?? Colors.black26;
    final widths = element.colWidths;
    final totalW = widths?.fold<double>(0, (a, b) => a + b) ?? element.frame.w;
    return Table(
      border: TableBorder.all(color: borderColor, width: 0.5),
      columnWidths: widths == null
          ? null
          : {
              for (final (i, w) in widths.indexed)
                i: FractionColumnWidth(w / totalW),
            },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final (r, row) in element.rows.indexed)
          TableRow(
            decoration: r == 0 && element.headerFill != null
                ? BoxDecoration(color: _color(element.headerFill))
                : null,
            children: [
              for (final cell in row)
                Padding(
                  padding: EdgeInsets.all(0.04 * scale),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        for (final run in cell.runs)
                          TextSpan(
                            text: run.text,
                            style: _runStyle(
                              run,
                              scale,
                              fallback: r == 0
                                  ? _color(element.headerColor)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    textAlign: _textAlign(cell.align),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
