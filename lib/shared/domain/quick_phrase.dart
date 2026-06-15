import 'package:freezed_annotation/freezed_annotation.dart';

part 'quick_phrase.freezed.dart';
part 'quick_phrase.g.dart';

/// A reusable quick phrase. Mirrors `QuickPhrase`
/// (`src/shared/types/index.ts`). Note `createdAt` / `updatedAt` are epoch
/// numbers in the source (not ISO strings), so they stay [int].
@freezed
abstract class QuickPhrase with _$QuickPhrase {
  const factory QuickPhrase({
    required String id,
    required String title,
    required String content,
    required int createdAt,
    required int updatedAt,
    int? order,
  }) = _QuickPhrase;

  factory QuickPhrase.fromJson(Map<String, dynamic> json) =>
      _$QuickPhraseFromJson(json);
}
