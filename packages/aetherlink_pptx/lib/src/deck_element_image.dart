// image 元素：内嵌图片（<p:pic>），data 内联 base64 或 src 引用。
part of 'deck_document.dart';

/// An embedded picture (`<p:pic>`), sourced from base64 PNG/JPEG data or a
/// not-yet-resolved `src` reference (URL / workspace path) — 工具层在导出前
/// 把 src 展开为 data；预览对未展开的 src 显示占位。
class DeckImageElement extends DeckElement {
  const DeckImageElement({required super.frame, required this.bytes, this.src});

  factory DeckImageElement.fromJson(Map<String, Object?> json, String where) {
    final data = json['data'];
    final src = json['src'];
    if (data is! String || data.isEmpty) {
      if (src is String && src.trim().isNotEmpty) {
        return DeckImageElement(
          frame: DeckFrame.fromJson(json, where),
          bytes: Uint8List(0),
          src: src.trim(),
        );
      }
      throw DeckParseException(
        '$where 缺少 "data"（base64 编码的 PNG/JPEG）或 "src"（图片 URL / 工作区路径）',
      );
    }
    final Uint8List bytes;
    try {
      bytes = base64Decode(data.replaceAll(RegExp(r'\s'), ''));
    } on FormatException {
      throw DeckParseException('$where 的 data 不是合法 base64');
    }
    if (detectImageFormat(bytes) == null) {
      throw DeckParseException('$where 的图片数据不是 PNG 或 JPEG');
    }
    return DeckImageElement(
      frame: DeckFrame.fromJson(json, where),
      bytes: bytes,
    );
  }

  final Uint8List bytes;

  /// Unresolved image reference (URL or workspace path); null once embedded.
  final String? src;

  bool get isResolved => bytes.isNotEmpty;
}
