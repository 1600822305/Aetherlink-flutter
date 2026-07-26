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

/// 内容页纯文本字数低于此值且无图表/表格/图片时触发 underfill。
const int kQaMinContentChars = 20;

/// 单元素占画布面积比例超过此值（且不是满幅背景装饰）触发 anchor_overexpansion。
const double kQaAnchorAreaRatio = 0.65;

/// 占满画布这个比例以上的元素视为背景装饰，不计入 anchor 检查。
const double _backdropAreaRatio = 0.92;

/// 连续同布局内容页达到此数触发 deck_rhythm_clone。
const int kQaRhythmCloneRun = 3;

/// 内容页布局类型（非 cover/toc/section/end 页型）。
const Set<String> _kContentLayoutTypes = {
  'focus',
  'split',
  'asymmetric',
  'columns',
  'hierarchy',
  'hero',
  'grid',
};

/// Runs deterministic layout / density checks on [deck] — the mobile-side
/// replacement for the desktop skills' render-to-image QA loop. Returns all
/// findings; an empty list means the deck passed.
List<DeckQaIssue> runDeckQa(DeckDocument deck) {
  final issues = <DeckQaIssue>[];
  final slideW = deck.layout.widthInches;
  final slideH = deck.layout.heightInches;

  var sameLayoutRun = 0;
  String? prevContentLayout;

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
    } else if (slide.layoutType == null ||
        _kContentLayoutTypes.contains(slide.layoutType)) {
      // underfill 升级：内容页（非封面/目录/章节/结束页）文字太少且
      // 没有图表/表格/图片支撑时提醒内容太薄。
      final chars = _plainTextChars(slide);
      final hasRichElement = slide.elements.any(
        (e) =>
            e is DeckChartElement ||
            e is DeckTableElement ||
            e is DeckImageElement,
      );
      if (chars < kQaMinContentChars && !hasRichElement) {
        issues.add(
          DeckQaIssue(
            severity: DeckQaSeverity.warning,
            rule: 'underfill',
            slideIndex: slideIndex,
            message:
                '内容太薄（纯文本仅 $chars 字且无图表/表格/图片）：'
                '补充支撑内容或并入相邻页',
          ),
        );
      }
    }

    // support_collapse：多卡内容页卡片类型单一，支撑层次不足（卡数下限
    // 由布局引擎在解析期强制，这里只查类型多样性）。
    if (_kContentLayoutTypes.contains(slide.layoutType) &&
        slide.layoutCardCount != null) {
      final cards = slide.layoutCardCount!;
      final types = slide.layoutCardTypeCount ?? 1;
      if (cards >= 3 && types < 2) {
        issues.add(
          DeckQaIssue(
            severity: DeckQaSeverity.warning,
            rule: 'support_collapse',
            slideIndex: slideIndex,
            message: '$cards 张卡片类型全部相同：混用 data/list/tags 等类型增加层次',
          ),
        );
      }
    }

    // deck_rhythm_clone：连续 kQaRhythmCloneRun 页同一内容布局。
    final contentLayout = _kContentLayoutTypes.contains(slide.layoutType)
        ? slide.layoutType
        : null;
    if (contentLayout != null && contentLayout == prevContentLayout) {
      sameLayoutRun += 1;
      if (sameLayoutRun == kQaRhythmCloneRun) {
        issues.add(
          DeckQaIssue(
            severity: DeckQaSeverity.warning,
            rule: 'deck_rhythm_clone',
            slideIndex: slideIndex,
            message:
                '连续 $kQaRhythmCloneRun 页都是「$contentLayout」布局：'
                '交替密度/换布局制造节奏（密→疏→密）',
          ),
        );
      }
    } else {
      sameLayoutRun = 1;
    }
    prevContentLayout = contentLayout;
    // 布局引擎生成的页元素数由引擎保证（卡片会展开成多个原子元素，
    // 用户无法控制），over_density 只对手写坐标页有意义。
    if (slide.layoutType == null &&
        slide.elements.length > kQaMaxElementsPerSlide) {
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
      // anchor_overexpansion：手写坐标页上单元素霸占画布（非满幅背景装饰）
      // 且页上还有其它内容被挤压；布局引擎生成的页几何有保证，不检查。
      final areaRatio = (frame.w * frame.h) / (slideW * slideH);
      if (slide.layoutType == null &&
          areaRatio > kQaAnchorAreaRatio &&
          areaRatio < _backdropAreaRatio &&
          slide.elements.length >= 3) {
        issues.add(
          DeckQaIssue(
            severity: DeckQaSeverity.warning,
            rule: 'anchor_overexpansion',
            slideIndex: slideIndex,
            elementIndex: elementIndex,
            message:
                '单个元素占画布 ${(areaRatio * 100).round()}%（超过 '
                '${(kQaAnchorAreaRatio * 100).round()}%）：缩小锚点元素，'
                '给支撑内容留出空间',
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

int _plainTextChars(DeckSlide slide) {
  var chars = 0;
  for (final element in slide.elements) {
    if (element is! DeckTextElement) continue;
    for (final paragraph in element.paragraphs) {
      for (final run in paragraph.runs) {
        chars += run.text.trim().length;
      }
    }
  }
  return chars;
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
