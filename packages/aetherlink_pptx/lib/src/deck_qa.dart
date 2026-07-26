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

/// Full-width (CJK/kana/hangul/emoji) character width as a fraction of font
/// size, used by the text-overflow heuristic.
/// 布局引擎为自产文本框预留宽度时用同一套估算，保证自产元素过得了自己的 QA。
const double kQaCharWidthFactor = 0.95;

/// Latin / digit / punctuation average width as a fraction of font size.
/// 按 0.95 全角估算拉丁数字会高估近一倍，导致大量"实际放得下"的误报。
const double kQaLatinCharWidthFactor = 0.55;

/// Estimated rendered width of [text] at [sizePt], in inches — per-rune
/// full-width vs latin factors. QA 与布局引擎必须共用这一个估算。
double qaTextWidthInches(String text, double sizePt) {
  var units = 0.0;
  for (final r in text.runes) {
    units += _isFullWidth(r) ? kQaCharWidthFactor : kQaLatinCharWidthFactor;
  }
  return units * sizePt / 72;
}

bool _isFullWidth(int rune) =>
    (rune >= 0x1100 && rune <= 0x115F) || // Hangul Jamo
    (rune >= 0x2E80 && rune <= 0xA4CF) || // CJK 部首/注音/汉字/彝文
    (rune >= 0xAC00 && rune <= 0xD7A3) || // Hangul 音节
    (rune >= 0xF900 && rune <= 0xFAFF) || // CJK 兼容表意
    (rune >= 0xFE30 && rune <= 0xFE4F) || // CJK 兼容符号
    (rune >= 0xFF00 && rune <= 0xFF60) || // 全角标点/字母
    rune >= 0x1F000; // emoji 及以上

/// Line height as a multiple of font size.
const double kQaLineHeightFactor = 1.25;

/// Overflow fires when estimated height exceeds frame height × this factor.
const double kQaTextOverflowTolerance = 1.15;

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
      textWidth += qaTextWidthInches(run.text, size);
    }
    if (maxSize == 0) maxSize = 18;
    final lineHeight =
        maxSize * kQaLineHeightFactor * (element.lineSpacing ?? 1) / 72;
    final lines = element.frame.w <= 0
        ? 1
        : (textWidth / element.frame.w).ceil().clamp(1, 1000);
    estimatedHeight += lines * lineHeight;
  }
  if (element.frame.h > 0 &&
      estimatedHeight > element.frame.h * kQaTextOverflowTolerance) {
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
