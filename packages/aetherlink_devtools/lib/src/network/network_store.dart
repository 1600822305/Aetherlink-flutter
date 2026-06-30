import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'network_entry.dart';

/// The Network panel's data layer: a bounded ring buffer of [NetworkEntry] plus
/// the active filter, exposed as [ValueListenable]s the UI listens to.
///
/// Use the [instance] singleton. [DioDevInterceptor] feeds it (one entry per
/// request, then mutated in place as the response — or each SSE/LLM chunk —
/// arrives); the panel reads [entries]/[filtered]. Dependency-free of Riverpod,
/// exactly like [ConsoleStore].
class NetworkStore {
  NetworkStore._();

  static final NetworkStore instance = NetworkStore._();

  /// Hard cap on retained requests (oldest dropped first). Lower than the
  /// console's cap since each entry can hold a full response body.
  static const int maxEntries = 500;

  final ListQueue<NetworkEntry> _buffer = ListQueue<NetworkEntry>();
  final Map<int, NetworkEntry> _byId = <int, NetworkEntry>{};
  int _nextId = 0;

  final ValueNotifier<List<NetworkEntry>> _entries =
      ValueNotifier<List<NetworkEntry>>(const <NetworkEntry>[]);
  final ValueNotifier<NetworkFilter> _filter =
      ValueNotifier<NetworkFilter>(const NetworkFilter());

  /// All retained entries, oldest → newest.
  ValueListenable<List<NetworkEntry>> get entries => _entries;

  /// The active filter (methods + statuses + search + toggles).
  ValueListenable<NetworkFilter> get filter => _filter;

  /// Records the start of a request and returns its id (the interceptor stashes
  /// this in `RequestOptions.extra` and passes it back to the update methods).
  int start({
    required String method,
    required String url,
    Map<String, String> requestHeaders = const <String, String>{},
    String? requestPayload,
    int? requestSize,
  }) {
    final id = _nextId++;
    final entry = NetworkEntry(
      id: id,
      method: method.toUpperCase(),
      url: url,
      requestHeaders: requestHeaders,
      requestPayload: requestPayload,
      requestSize: requestSize,
    );
    _buffer.add(entry);
    _byId[id] = entry;
    _trim();
    _publish();
    return id;
  }

  /// Finalises a non-streaming response: records status/headers/body and flips
  /// the entry to `success` (2xx/3xx) or `error`.
  void completeResponse(
    int id, {
    required int statusCode,
    String? statusText,
    Map<String, String> headers = const <String, String>{},
    String? body,
    int? size,
  }) {
    final e = _byId[id];
    if (e == null) return;
    e
      ..statusCode = statusCode
      ..statusText = statusText
      ..responseHeaders = headers
      ..responseData = body
      ..responseSize = size ?? body?.length
      ..endTime = DateTime.now()
      ..status = _statusFor(statusCode);
    _publish();
  }

  /// Marks an entry as a stream and records its status/headers; the body then
  /// arrives via [appendStream] and is sealed by [endStream].
  void beginStream(
    int id, {
    required int statusCode,
    String? statusText,
    Map<String, String> headers = const <String, String>{},
  }) {
    final e = _byId[id];
    if (e == null) return;
    e
      ..isStream = true
      ..statusCode = statusCode
      ..statusText = statusText
      ..responseHeaders = headers
      ..responseData ??= ''
      ..responseSize ??= 0;
    _publish();
  }

  /// Appends a streamed chunk (raw bytes) to the entry's response body.
  void appendStream(int id, List<int> bytes, String text) {
    final e = _byId[id];
    if (e == null) return;
    e
      ..responseData = (e.responseData ?? '') + text
      ..responseSize = (e.responseSize ?? 0) + bytes.length;
    _publish();
  }

  /// Seals a stream once its last chunk arrived, flipping it to its final state.
  void endStream(int id, {bool cancelled = false}) {
    final e = _byId[id];
    if (e == null) return;
    e
      ..endTime = DateTime.now()
      ..status = cancelled
          ? NetworkStatus.cancelled
          : _statusFor(e.statusCode ?? 0);
    _publish();
  }

  /// Records a failed request (network error, non-2xx that threw, or a cancel).
  void completeError(
    int id, {
    String? message,
    String? stack,
    int? statusCode,
    String? statusText,
    Map<String, String> headers = const <String, String>{},
    String? body,
    bool cancelled = false,
  }) {
    final e = _byId[id];
    if (e == null) return;
    e
      ..statusCode = statusCode ?? e.statusCode
      ..statusText = statusText ?? e.statusText
      ..responseHeaders = headers.isEmpty ? e.responseHeaders : headers
      ..responseData = body ?? e.responseData
      ..error = message
      ..errorStack = stack
      ..endTime = DateTime.now()
      ..status = cancelled ? NetworkStatus.cancelled : NetworkStatus.error;
    _publish();
  }

  /// Flips a still-pending entry to `cancelled` (driven by a [CancelToken]).
  /// No-op once the entry has otherwise finalised, so a late cancel signal never
  /// clobbers a completed request.
  void markCancelled(int id) {
    final e = _byId[id];
    if (e == null || e.status != NetworkStatus.pending) return;
    e
      ..status = NetworkStatus.cancelled
      ..endTime ??= DateTime.now();
    _publish();
  }

  /// Clears all retained entries.
  void clear() {
    _buffer.clear();
    _byId.clear();
    _entries.value = const <NetworkEntry>[];
  }

  void setFilter(NetworkFilter value) => _filter.value = value;

  /// The entries matching the current [filter] — newest first (the list a
  /// DevTools network table reads top-to-bottom) — and what copy/export use.
  List<NetworkEntry> get filtered {
    final f = _filter.value;
    return _buffer.where(f.matches).toList(growable: false).reversed.toList(
      growable: false,
    );
  }

  /// Looks up a live entry by id (the drawer re-reads it on every stream tick).
  NetworkEntry? byId(int id) => _byId[id];

  static NetworkStatus _statusFor(int code) =>
      code >= 200 && code < 400 ? NetworkStatus.success : NetworkStatus.error;

  void _trim() {
    while (_buffer.length > maxEntries) {
      final dropped = _buffer.removeFirst();
      _byId.remove(dropped.id);
    }
  }

  void _publish() {
    _entries.value = List<NetworkEntry>.unmodifiable(_buffer);
  }
}

/// Immutable filter state for the Network panel: which methods/statuses are
/// visible, a free-text search over URL/method/status, and two quick toggles.
/// Mirrors the web `NetworkFilter`.
class NetworkFilter {
  const NetworkFilter({
    this.methods = const <String>{},
    this.statuses = const <NetworkStatus>{
      NetworkStatus.pending,
      NetworkStatus.success,
      NetworkStatus.error,
      NetworkStatus.cancelled,
    },
    this.search = '',
    this.onlyErrors = false,
  });

  /// Visible HTTP methods. Empty means "all" (so new verbs aren't hidden).
  final Set<String> methods;
  final Set<NetworkStatus> statuses;
  final String search;
  final bool onlyErrors;

  bool matches(NetworkEntry e) {
    if (methods.isNotEmpty && !methods.contains(e.method)) return false;
    if (!statuses.contains(e.status)) return false;
    if (onlyErrors && e.status != NetworkStatus.error) return false;
    if (search.isEmpty) return true;
    final q = search.toLowerCase();
    return e.url.toLowerCase().contains(q) ||
        e.method.toLowerCase().contains(q) ||
        (e.statusCode?.toString().contains(q) ?? false);
  }

  NetworkFilter copyWith({
    Set<String>? methods,
    Set<NetworkStatus>? statuses,
    String? search,
    bool? onlyErrors,
  }) => NetworkFilter(
    methods: methods ?? this.methods,
    statuses: statuses ?? this.statuses,
    search: search ?? this.search,
    onlyErrors: onlyErrors ?? this.onlyErrors,
  );
}
