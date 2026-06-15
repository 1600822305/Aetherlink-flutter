import 'package:freezed_annotation/freezed_annotation.dart';

part 'web_search_reference_item.freezed.dart';
part 'web_search_reference_item.g.dart';

/// A single web-search citation entry (unified citation system). Mirrors
/// `WebSearchReferenceItem` (`src/shared/types/newMessage.ts`).
@freezed
abstract class WebSearchReferenceItem with _$WebSearchReferenceItem {
  const factory WebSearchReferenceItem({
    required int index,
    required String title,
    required String url,
    String? snippet,
    String? content,
    String? provider,
  }) = _WebSearchReferenceItem;

  factory WebSearchReferenceItem.fromJson(Map<String, dynamic> json) =>
      _$WebSearchReferenceItemFromJson(json);
}
