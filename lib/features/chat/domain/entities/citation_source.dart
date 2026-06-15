import 'package:freezed_annotation/freezed_annotation.dart';

part 'citation_source.freezed.dart';
part 'citation_source.g.dart';

/// Legacy citation source entry kept for backward compatibility (the original
/// `CitationMessageBlock.sources[]` shape in `src/shared/types/newMessage.ts`).
@freezed
abstract class CitationSource with _$CitationSource {
  const factory CitationSource({String? title, String? url, String? content}) =
      _CitationSource;

  factory CitationSource.fromJson(Map<String, dynamic> json) =>
      _$CitationSourceFromJson(json);
}
