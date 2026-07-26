/// deck.json 源模型与解析器（library 入口）。
///
/// 职责拆分（同一 library 的 part 文件，公开 API 不变）：
/// - `deck_types.dart`        基础类型：异常/画布/颜色/几何/文本 run/段落
/// - `deck_element.dart`      DeckElement sealed 基类 + 元素解析注册表
/// - `deck_element_text.dart` / `_shape` / `_image` / `_table` / `_chart`
///   每种元素一个 codec 文件——新增元素只需加一个 part + 注册表登记
/// - 本文件               DeckSlide / DeckDocument（批量收错的组装层）
library;

import 'dart:convert';
import 'dart:typed_data';

import 'deck_layout_engine.dart';
import 'deck_style.dart';

part 'deck_types.dart';
part 'deck_element.dart';
part 'deck_element_text.dart';
part 'deck_element_shape.dart';
part 'deck_element_image.dart';
part 'deck_element_table.dart';
part 'deck_element_chart.dart';

/// One slide: background + z-ordered elements + optional speaker notes.
class DeckSlide {
  const DeckSlide({
    required this.elements,
    this.background,
    this.notes,
    this.layoutType,
    this.layoutCardCount,
    this.layoutCardTypeCount,
  });

  factory DeckSlide.fromJson(
    Map<String, Object?> json,
    String where, {
    DeckLayout canvas = DeckLayout.layout16x9,
    DeckStyle? style,
  }) {
    final rawElements = json['elements'];
    final rawLayout = json['layout'];
    if (rawElements is! List && rawLayout == null) {
      throw DeckParseException('$where 缺少数组 "elements"（或布局声明 "layout"）');
    }
    final rawNotes = json['notes'];
    if (rawNotes != null && rawNotes is! String) {
      throw DeckParseException('$where 的 "notes" 必须是字符串（演讲者备注）');
    }
    final notes = (rawNotes as String?)?.trim();
    final elements = <DeckElement>[];
    String? layoutType;
    int? layoutCardCount;
    int? layoutCardTypeCount;
    // 布局引擎：页级 layout 声明编译成绝对定位元素；仍可与 elements 混用
    // （layout 元素在前，elements 叠加在后）。
    // 批量收集：一个元素解析失败不中断整页，攒齐所有错误一次性抛出，
    // 让 agent 一轮就能修完（编译器风格）。
    final errors = <String>[];
    if (rawLayout != null) {
      try {
        final layoutMap = _asMap(rawLayout, '$where.layout');
        elements.addAll(buildLayoutElements(layoutMap, canvas, style, where));
        // 保留布局元信息供 QA 的失败模式规则（节奏克隆/支撑坍缩）使用。
        layoutType = layoutMap['type'] as String?;
        final cards = layoutMap['cards'];
        if (cards is List) {
          layoutCardCount = cards.length;
          layoutCardTypeCount = {
            for (final c in cards)
              if (c is Map) (c['type'] as String?) ?? 'text',
          }.length;
        }
      } on DeckParseException catch (e) {
        errors.addAll(e.messages);
      }
    }
    if (rawElements is List) {
      for (final (i, e) in rawElements.indexed) {
        try {
          final map = _asMap(e, '$where.elements[$i]');
          if (map['type'] == 'infographic') {
            elements.addAll(
              buildInfographicElements(map, style, '$where.elements[$i]'),
            );
          } else {
            elements.add(
              DeckElement.fromJson(map, '$where.elements[$i]', style: style),
            );
          }
        } on DeckParseException catch (ex) {
          errors.addAll(ex.messages);
        }
      }
    }
    if (errors.isNotEmpty) throw DeckParseException.all(errors);
    return DeckSlide(
      background: json['background'] == null
          ? style?.background
          : DeckColor(json['background'] as String),
      notes: notes == null || notes.isEmpty ? null : notes,
      elements: elements,
      layoutType: layoutType,
      layoutCardCount: layoutCardCount,
      layoutCardTypeCount: layoutCardTypeCount,
    );
  }

  final DeckColor? background;
  final List<DeckElement> elements;

  /// Speaker notes, written into the slide's `notesSlide` part on export.
  final String? notes;

  /// Layout metadata (when the slide used a page-level layout declaration),
  /// consumed by the failure-mode QA rules; null for absolute-positioned pages.
  final String? layoutType;
  final int? layoutCardCount;
  final int? layoutCardTypeCount;
}

/// The whole deck source — the structured JSON the agent produces and both
/// the PPTX writer and the HTML preview renderer consume.
class DeckDocument {
  const DeckDocument({
    required this.layout,
    required this.slides,
    this.title,
    this.style,
  });

  /// Parses and validates a deck.json object (or JSON string via
  /// [DeckDocument.parse]). Throws [DeckParseException] with an actionable
  /// message on any structural problem.
  factory DeckDocument.fromJson(Map<String, Object?> json) {
    final rawSlides = json['slides'];
    if (rawSlides is! List || rawSlides.isEmpty) {
      throw DeckParseException('deck 缺少非空数组 "slides"');
    }
    final layout = DeckLayout.parse(json['layout'] as String?);
    final style = DeckStyle.resolve(json['style'], 'deck.style');
    // 批量收集：坏页不中断整个 deck 的解析，所有页的错误一次性返回。
    final slides = <DeckSlide>[];
    final errors = <String>[];
    for (final (i, s) in rawSlides.indexed) {
      try {
        slides.add(
          DeckSlide.fromJson(
            _asMap(s, 'slides[$i]'),
            'slides[$i]',
            canvas: layout,
            style: style,
          ),
        );
      } on DeckParseException catch (e) {
        errors.addAll(e.messages);
      }
    }
    if (errors.isNotEmpty) throw DeckParseException.all(errors);
    return DeckDocument(
      layout: layout,
      style: style,
      title: json['title'] as String?,
      slides: slides,
    );
  }

  /// Parses a raw JSON string.
  factory DeckDocument.parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw DeckParseException('deck JSON 解析失败: ${e.message}');
    }
    return DeckDocument.fromJson(_asMap(decoded, 'deck'));
  }

  final DeckLayout layout;
  final String? title;
  final List<DeckSlide> slides;

  /// Deck-wide visual style（内置 id 或内联对象）; null = 无风格推导.
  final DeckStyle? style;
}

Map<String, Object?> _asMap(Object? value, String where) {
  if (value is Map) return value.cast<String, Object?>();
  throw DeckParseException('$where 必须是 JSON 对象');
}
