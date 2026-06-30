/// Value types for the Network panel. Plain Dart (no codegen) so the package
/// stays self-contained, mirroring `models/log_entry.dart`.
///
/// Mirrors the original web's `NetworkEntry` / `NetworkStatus`
/// (`EnhancedNetworkService.ts`) so the UI, filters and exports line up across
/// the two apps. Unlike the immutable [LogEntry], a [NetworkEntry] is mutable:
/// a request starts as `pending` and is filled in as the response (and, for
/// streaming/SSE responses, each chunk) arrives.
library;

/// Lifecycle of a captured request, ordered as the UI lists them.
///
/// `pending` covers both an in-flight request and an open SSE/LLM stream still
/// receiving chunks; it flips to `success`/`error` once the body (or stream)
/// completes, or `cancelled` when a [CancelToken] aborts it.
enum NetworkStatus {
  pending('PENDING'),
  success('SUCCESS'),
  error('ERROR'),
  cancelled('CANCELLED');

  const NetworkStatus(this.label);

  final String label;
}

/// A single captured HTTP exchange shown as one row in the Network panel and,
/// when tapped, expanded into the Headers / Payload / Response / Timing drawer.
///
/// Fed by [DioDevInterceptor] (request → response/stream → completion) and held
/// in the [NetworkStore] ring buffer.
class NetworkEntry {
  NetworkEntry({
    required this.id,
    required this.method,
    required this.url,
    DateTime? startTime,
    this.requestHeaders = const <String, String>{},
    this.requestPayload,
    this.requestSize,
  }) : startTime = startTime ?? DateTime.now();

  /// Monotonic identifier (assigned by the store) — stable for selection/keys.
  final int id;

  /// Upper-case HTTP verb, e.g. `POST`.
  final String method;
  final String url;
  final DateTime startTime;

  /// Request headers, captured verbatim (no redaction — see [DioDevInterceptor]).
  Map<String, String> requestHeaders;

  /// Serialised request body, or `null` for bodyless requests.
  String? requestPayload;
  int? requestSize;

  NetworkStatus status = NetworkStatus.pending;
  int? statusCode;
  String? statusText;

  DateTime? endTime;

  /// Sanitised response headers.
  Map<String, String> responseHeaders = const <String, String>{};

  /// Accumulated response body. For streaming responses this grows chunk by
  /// chunk as [NetworkStore.appendStream] is called.
  String? responseData;
  int? responseSize;

  /// True once the response was detected as a stream (`ResponseType.stream`,
  /// `text/event-stream`, …) — the drawer renders it chunk-aware.
  bool isStream = false;

  /// Error message + stack for failed requests.
  String? error;
  String? errorStack;

  /// Wall-clock latency, or `null` while still pending.
  Duration? get duration => endTime?.difference(startTime);

  bool get isError => status == NetworkStatus.error;

  /// The host + path shown as the row's primary label (query stripped for
  /// brevity; the full URL lives in the drawer).
  String get shortUrl {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final path = uri.path.isEmpty ? '/' : uri.path;
    return uri.hasAuthority ? '${uri.host}$path' : path;
  }

  /// A flat, copy/share-friendly dump used by the drawer's "copy" action and the
  /// page-level export, mirroring the web `generateDetailsText`.
  String toDetailText() {
    final b = StringBuffer()
      ..writeln('=== 网络请求详情 ===')
      ..writeln()
      ..writeln('URL: $url')
      ..writeln('Method: $method')
      ..writeln('Status: ${statusCode ?? status.label}');
    if (duration != null) b.writeln('Duration: ${formatDuration(duration!)}');
    if (responseSize != null) {
      b.writeln('Response Size: ${formatSize(responseSize!)}');
    }
    b
      ..writeln()
      ..writeln('=== Request Headers ===')
      ..writeln(_mapText(requestHeaders));
    if (requestPayload != null && requestPayload!.isNotEmpty) {
      b
        ..writeln()
        ..writeln('=== Request Body ===')
        ..writeln(requestPayload);
    }
    b
      ..writeln()
      ..writeln('=== Response Headers ===')
      ..writeln(_mapText(responseHeaders));
    if (responseData != null && responseData!.isNotEmpty) {
      b
        ..writeln()
        ..writeln('=== Response Body ===')
        ..writeln(responseData);
    }
    if (error != null) {
      b
        ..writeln()
        ..writeln('=== Error ===')
        ..writeln(error);
      if (errorStack != null) b.writeln(errorStack);
    }
    return b.toString().trimRight();
  }

  /// A `curl` command reproducing this request, with full headers — directly
  /// runnable (the panel doesn't redact, like browser devtools).
  String toCurl() {
    String esc(String s) => s.replaceAll("'", r"'\''");
    final b = StringBuffer("curl -X $method '${esc(url)}'");
    for (final h in requestHeaders.entries) {
      b.write(" \\\n  -H '${esc(h.key)}: ${esc(h.value)}'");
    }
    if (requestPayload != null && requestPayload!.isNotEmpty) {
      b.write(" \\\n  --data '${esc(requestPayload!)}'");
    }
    return b.toString();
  }

  static String _mapText(Map<String, String> m) {
    if (m.isEmpty) return '(none)';
    return m.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }
}

/// Human-readable byte size, mirroring the web `formatSize` (`1.2 KB`).
String formatSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  final text = i == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text ${units[i]}';
}

/// Human-readable latency, mirroring the web `formatDuration` (`820ms` / `1.20s`).
String formatDuration(Duration d) {
  final ms = d.inMilliseconds;
  if (ms < 1000) return '${ms}ms';
  return '${(ms / 1000).toStringAsFixed(2)}s';
}
