// DeckElement sealed 基类 + 元素解析注册表。
part of 'deck_document.dart';

/// 一种元素类型的 JSON 解析器。
typedef DeckElementParser =
    DeckElement Function(Map<String, Object?> json, String where, DeckStyle? style);

/// 元素类型注册表：新增元素种类只需在这里登记一行 + 加一个 part 文件，
/// 不必改 [DeckElement.fromJson]（infographic 是展开为多元素的宏，
/// 在 DeckSlide 层单独处理）。
final Map<String, DeckElementParser> _deckElementParsers = {
  'text': (j, w, s) => DeckTextElement.fromJson(j, w, style: s),
  'shape': (j, w, s) => DeckShapeElement.fromJson(j, w),
  'image': (j, w, s) => DeckImageElement.fromJson(j, w),
  'table': (j, w, s) => DeckTableElement.fromJson(j, w, style: s),
  'chart': (j, w, s) => DeckChartElement.fromJson(j, w, style: s),
};

/// Element variants a slide can carry.
sealed class DeckElement {
  const DeckElement({required this.frame});

  final DeckFrame frame;

  static DeckElement fromJson(
    Map<String, Object?> json,
    String where, {
    DeckStyle? style,
  }) {
    final type = json['type'];
    final parser = type is String ? _deckElementParsers[type] : null;
    if (parser == null) {
      throw DeckParseException(
        '$where 的 type 必须是 '
        '${_deckElementParsers.keys.join('/')}/infographic：收到 "$type"',
      );
    }
    return parser(json, where, style);
  }
}
