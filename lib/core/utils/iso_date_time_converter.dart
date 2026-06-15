import 'package:json_annotation/json_annotation.dart';

/// Converts the original web app's ISO-8601 timestamp strings to/from
/// [DateTime].
///
/// All domain timestamp fields use this so the in-memory model holds real
/// [DateTime]s while the persisted wire shape stays an ISO string, matching the
/// data the React app wrote to IndexedDB. json_serializable applies it only to
/// non-null values, so the same converter also covers nullable fields.
class IsoDateTimeConverter implements JsonConverter<DateTime, String> {
  const IsoDateTimeConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json);

  @override
  String toJson(DateTime object) => object.toIso8601String();
}
