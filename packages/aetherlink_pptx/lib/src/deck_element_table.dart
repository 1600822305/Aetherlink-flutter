// table 元素：原生表格（<a:graphicFrame> 包 <a:tbl>）。
part of 'deck_document.dart';

/// A single table cell.
class DeckTableCell {
  const DeckTableCell({required this.runs, this.fill, this.align});

  final List<DeckTextRun> runs;
  final DeckColor? fill;
  final String? align;

  String get plainText => runs.map((r) => r.text).join();
}

/// A native table (`<a:graphicFrame>` wrapping `<a:tbl>`).
class DeckTableElement extends DeckElement {
  const DeckTableElement({
    required super.frame,
    required this.rows,
    this.colWidths,
    this.headerFill,
    this.headerColor,
    this.borderColor,
  });

  factory DeckTableElement.fromJson(
    Map<String, Object?> json,
    String where, {
    DeckStyle? style,
  }) {
    final rawRows = json['rows'];
    if (rawRows is! List || rawRows.isEmpty) {
      throw DeckParseException('$where 缺少非空数组 "rows"');
    }
    final rows = <List<DeckTableCell>>[];
    int? columnCount;
    for (final (r, rawRow) in rawRows.indexed) {
      if (rawRow is! List || rawRow.isEmpty) {
        throw DeckParseException('$where.rows[$r] 必须是非空数组');
      }
      columnCount ??= rawRow.length;
      if (rawRow.length != columnCount) {
        throw DeckParseException('$where 每行的列数必须一致');
      }
      final cells = <DeckTableCell>[];
      for (final (c, rawCell) in rawRow.indexed) {
        final cellWhere = '$where.rows[$r][$c]';
        // 风格推导：省略颜色/字体的单元格文字用风格正文色与字体栈，
        // 与 DeckTextElement 一致（否则深色风格下表格文字落回默认黑色）。
        if (rawCell is String) {
          cells.add(
            DeckTableCell(
              runs: [
                DeckTextRun(
                  text: rawCell,
                  color: style?.textPrimary,
                  font: style?.bodyFont,
                ),
              ],
            ),
          );
          continue;
        }
        final map = _asMap(rawCell, cellWhere);
        final align = map['align'] as String?;
        if (align != null &&
            !const {'left', 'center', 'right'}.contains(align)) {
          throw DeckParseException('$cellWhere 的 align 只支持 left/center/right');
        }
        final rawRuns = map['runs'];
        cells.add(
          DeckTableCell(
            runs: rawRuns is List
                ? [
                    for (final (i, run) in rawRuns.indexed)
                      DeckTextRun.fromJson(
                        _asMap(run, '$cellWhere.runs[$i]'),
                        '$cellWhere.runs[$i]',
                        style: style,
                      ),
                  ]
                : [
                    DeckTextRun(
                      text: (map['text'] ?? '').toString(),
                      color: style?.textPrimary,
                      font: style?.bodyFont,
                    ),
                  ],
            fill: map['fill'] == null ? null : DeckColor(map['fill'] as String),
            align: align,
          ),
        );
      }
      rows.add(cells);
    }
    final rawColW = json['colWidths'];
    List<double>? colWidths;
    if (rawColW != null) {
      if (rawColW is! List ||
          rawColW.length != columnCount ||
          rawColW.any((w) => w is! num || w <= 0)) {
        throw DeckParseException('$where 的 colWidths 必须是与列数等长的正数数组（单位英寸）');
      }
      colWidths = [for (final w in rawColW) (w as num).toDouble()];
    }
    return DeckTableElement(
      frame: DeckFrame.fromJson(json, where),
      rows: rows,
      colWidths: colWidths,
      headerFill: json['headerFill'] == null
          ? null
          : DeckColor(json['headerFill'] as String),
      headerColor: json['headerColor'] == null
          ? null
          : DeckColor(json['headerColor'] as String),
      borderColor: json['borderColor'] == null
          ? null
          : DeckColor(json['borderColor'] as String),
    );
  }

  final List<List<DeckTableCell>> rows;

  /// Column widths in inches; null = equal split of the frame width.
  final List<double>? colWidths;
  final DeckColor? headerFill;
  final DeckColor? headerColor;
  final DeckColor? borderColor;

  int get columnCount => rows.first.length;
}
