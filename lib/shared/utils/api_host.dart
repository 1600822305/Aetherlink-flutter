/// API base-URL normalization, ported 1:1 from Cherry Studio's `formatApiHost`
/// (`src/shared/utils/api`). Providers store a bare host (e.g.
/// `https://api.openai.com`); the OpenAI-compatible endpoints need the API
/// version segment (`/v1`) appended unless the user opted out. The rules:
///
///  * trim whitespace and drop a single trailing `/`;
///  * a trailing `#` is the escape hatch — strip it and append **nothing**
///    (the user is declaring the exact base);
///  * a host that already carries a trailing version (`/v1`, `/v2beta`, …) is
///    left untouched;
///  * otherwise append `/<apiVersion>` (default `v1`).
library;

/// Matches a `/v<number>[alpha|beta]` version segment anywhere in a path.
final RegExp _versionRegex = RegExp(
  r'/v\d+(?:alpha|beta)?(?:/|$)',
  caseSensitive: false,
);

/// Whether [host]'s path already contains an API version segment (e.g. `/v1`).
bool hasApiVersion(String host) {
  if (host.isEmpty) return false;
  final uri = Uri.tryParse(host);
  final target =
      (uri != null && uri.hasScheme && uri.hasAuthority) ? uri.path : host;
  return _versionRegex.hasMatch(target);
}

/// Normalizes an API [host], appending [apiVersion] (default `v1`) when missing.
///
/// Returns `''` for a null/blank host (or a bare `#`). Set [supportApiVersion]
/// to false for protocols that must not get a version suffix.
String formatApiHost(
  String? host, {
  bool supportApiVersion = true,
  String apiVersion = 'v1',
}) {
  final normalized = (host ?? '').trim().replaceFirst(RegExp(r'/$'), '');
  if (normalized.isEmpty) return '';

  final shouldAppend = !(normalized.endsWith('#') ||
      !supportApiVersion ||
      hasApiVersion(normalized));

  if (shouldAppend) return '$normalized/$apiVersion';
  return normalized.replaceFirst(RegExp(r'#$'), '');
}
