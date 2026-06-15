import 'package:dio/dio.dart';

/// Builds the shared [Dio] used by every LLM protocol adapter.
///
/// Mechanical plumbing only (connect / receive timeouts; a swappable
/// [Dio.httpClientAdapter] so tests can feed recorded bytes without a network).
/// Provider-specific auth headers, request bodies and endpoints live in the
/// adapters, never here — this layer carries no protocol semantics
/// (ADR-0004 / ADR-0006).
Dio buildLlmDio() {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      // Streamed completions can run for minutes; keep the socket open.
      receiveTimeout: const Duration(minutes: 5),
      headers: const {Headers.contentTypeHeader: Headers.jsonContentType},
    ),
  );
}
