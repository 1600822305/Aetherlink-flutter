/// Thrown when the input bytes are not a valid package for the requested
/// format (bad zip, or a required part is missing / malformed).
class OfficeParseException implements Exception {
  OfficeParseException(this.message);

  final String message;

  @override
  String toString() => 'OfficeParseException: $message';
}
