import 'package:freezed_annotation/freezed_annotation.dart';

part 'custom_parameter.freezed.dart';
part 'custom_parameter.g.dart';

/// Declared value kind of a [CustomParameter]. Mirrors `CustomParameterType`
/// (`src/shared/types/Assistant.ts`).
enum CustomParameterType {
  @JsonValue('string')
  string,
  @JsonValue('number')
  number,
  @JsonValue('boolean')
  boolean,
  @JsonValue('json')
  json,
}

/// A user-defined request parameter for an assistant. Mirrors
/// `CustomParameter` (`src/shared/types/Assistant.ts`). `value` is
/// `string | number | boolean | object` in the source, so it stays a dynamic
/// [Object].
@freezed
abstract class CustomParameter with _$CustomParameter {
  const factory CustomParameter({
    required String name,
    required Object? value,
    required CustomParameterType type,
  }) = _CustomParameter;

  factory CustomParameter.fromJson(Map<String, dynamic> json) =>
      _$CustomParameterFromJson(json);
}
