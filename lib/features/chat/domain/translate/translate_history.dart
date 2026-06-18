/// A single translation history record, a pure-Dart port of the web
/// `TranslateHistory` (`src/shared/services/translate/TranslateService.ts`).
///
/// Stored as a JSON list under the `translate_history` setting key (the web
/// keeps it in `localStorage`); [toJson] / [fromJson] match the web field names
/// so existing payloads stay interchangeable.
class TranslateHistory {
  const TranslateHistory({
    required this.id,
    required this.sourceText,
    required this.targetText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.createdAt,
    this.star = false,
  });

  factory TranslateHistory.fromJson(Map<String, dynamic> json) {
    return TranslateHistory(
      id: (json['id'] ?? '').toString(),
      sourceText: (json['sourceText'] ?? '').toString(),
      targetText: (json['targetText'] ?? '').toString(),
      sourceLanguage: (json['sourceLanguage'] ?? 'auto').toString(),
      targetLanguage: (json['targetLanguage'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      star: json['star'] == true,
    );
  }

  final String id;
  final String sourceText;
  final String targetText;

  /// The source language `langCode`, or `auto` when auto-detected.
  final String sourceLanguage;

  /// The target language `langCode`.
  final String targetLanguage;
  final DateTime createdAt;
  final bool star;

  TranslateHistory copyWith({bool? star}) {
    return TranslateHistory(
      id: id,
      sourceText: sourceText,
      targetText: targetText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      createdAt: createdAt,
      star: star ?? this.star,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceText': sourceText,
    'targetText': targetText,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    'createdAt': createdAt.toIso8601String(),
    'star': star,
  };
}
