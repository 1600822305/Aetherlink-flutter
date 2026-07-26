import 'deck_document.dart';

/// Severity of a QA finding: [error] should block delivery, [warning] is a
/// design-quality signal the agent may accept.
enum DeckQaSeverity { error, warning }

/// One QA finding on a deck: which slide/element, what rule fired, and an
/// actionable message the agent can act on to fix the source.
class DeckQaIssue {
  const DeckQaIssue({
    required this.severity,
    required this.rule,
    required this.slideIndex,
    required this.message,
    this.elementIndex,
  });

  final DeckQaSeverity severity;
  final String rule;

  /// 0-based slide index.
  final int slideIndex;

  /// 0-based element index within the slide; null for slide-level findings.
  final int? elementIndex;
  final String message;

  Map<String, Object?> toJson() => {
    'severity': severity.name,
    'rule': rule,
    'slide': slideIndex + 1,
    if (elementIndex != null) 'element': elementIndex! + 1,
    'message': message,
  };
}

/// Minimum readable font size (pt) before a warning fires.
const double kQaMinFontSize = 12;

/// Maximum elements per slide before an over-density warning fires.
const int kQaMaxElementsPerSlide = 12;

/// Average character width as a fraction of font size — a conservative
/// CJK-leaning estimate used by the text-overflow heuristic (CJK glyphs are
/// full-width; latin averages ~0.55, so 0.95 leaves margin for mixed text).
const double _charWidthFactor = 0.95;

/// Line height as a multiple of font size.
const double _lineHeightFactor = 1.25;

/// Runs deterministic layout / density checks on [deck] — the mobile-side
/// replacement for the desktop skills' render-to-image QA loop. Returns all
/// findings; an empty list means the deck passed.
List<DeckQaIssue> runDeckQa(DeckDocument deck) {
  final issues = <DeckQaIssue>[];
  final slideW = deck.layout.widthInches;
  final slideH = deck.layout.heightInches;

  for (final (slideIndex, slide) in deck.slides.indexed) {
    if (slide.elements.isEmpty) {
      issues.add(
        DeckQaIssue(
          severity: DeckQaSeverity.warning,
          rule: 'underfill',
          slideIndex: slideIndex,
          message: '这一页没有任何元素（空白页）',
        ),
      );
    }
    if (slide.elements.length > kQaMaxElementsPerSlide) {
      issues.add(
        DeckQaIssue(
          severity: DeckQaSeverity.warning,
          rule: 'over_density',
          slideIndex: slideIndex,
          message:
              '这一页有 ${slide.elements.length} 个元素（超过 $kQaMaxElementsPerSlide），'
              '考虑拆分成多页',
        ),
      );
    }
    for (final (elementIndex, element) in slide.elements.indexed) {
      final frame = element.frame;
      if (frame.x < 0 ||
          frame.y < 0 ||
          frame.x + frame.w > slideW + 0.01 ||
          frame.y + frame.h > slideH + 0.01) {
        issues.add(
          DeckQaIssue(
            severity: DeckQaSeverity.error,
            rule: 'out_of_bounds',
            slideIndex: slideIndex,
            elementIndex: elementIndex,
            message:
                '元素超出画布（画布 ${slideW.toStringAsFixed(2)}×${slideH.toStringAsFixed(2)} 英寸，'
                '元素位于 x=${frame.x} y=${frame.y} w=${frame.w} h=${frame.h}）',
          ),
        );
      }
      if (element is DeckTextElement) {
        issues.addAll(
          _checkText(
            element,
            slideIndex: slideIndex,
            elementIndex: elementIndex,
          ),
        );
      }
    }
  }
  return issues;
}

List<DeckQaIssue> _checkText(
  DeckTextElement element, {
  required int slideIndex,
  required int elementIndex,
}) {
  final issues = <DeckQaIssue>[];
  var estimatedHeight = 0.0;
  for (final paragraph in element.paragraphs) {
    var maxSize = 0.0;
    var textWidth = 0.0;
    for (final run in paragraph.runs) {
      final size = run.size ?? 18;
      if (size < kQaMinFontSize && run.text.trim().isNotEmpty) {
        issues.add(
          DeckQaIssue(
            severity: DeckQaSeverity.warning,
            rule: 'font_too_small',
            slideIndex: slideIndex,
            elementIndex: elementIndex,
            message: '字号 ${size}pt 低于可读下限 ${kQaMinFontSize}pt',
          ),
        );
      }
      if (size > maxSize) maxSize = size;
      // pt → inches is /72; width per char ≈ size × factor.
      textWidth += run.text.length * size * _charWidthFactor / 72;
    }
    if (maxSize == 0) maxSize = 18;
    final lineHeight =
        maxSize * _lineHeightFactor * (element.lineSpacing ?? 1) / 72;
    final lines = element.frame.w <= 0
        ? 1
        : (textWidth / element.frame.w).ceil().clamp(1, 1000);
    estimatedHeight += lines * lineHeight;
  }
  if (element.frame.h > 0 && estimatedHeight > element.frame.h * 1.15) {
    issues.add(
      DeckQaIssue(
        severity: DeckQaSeverity.error,
        rule: 'text_overflow',
        slideIndex: slideIndex,
        elementIndex: elementIndex,
        message:
            '文本估算高度 ${estimatedHeight.toStringAsFixed(2)} 英寸超出容器 '
            '${element.frame.h} 英寸：精简文字、调小字号或加大容器',
      ),
    );
  }
  return issues;
}
