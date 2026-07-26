import 'dart:convert';
import 'dart:typed_data';

import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:dio/dio.dart';

/// Maps a dio [DioException] onto a [NetworkFailure]. Mechanical, provider-
/// agnostic plumbing (ADR-0006): adapters rethrow the result into their stream
/// so callers see a [Failure], never a raw dio type.
NetworkFailure networkFailureFromDio(DioException error) {
  final status = error.response?.statusCode;
  final reason = switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      'Request to ${error.requestOptions.uri} timed out',
    DioExceptionType.badResponse =>
      'Provider returned HTTP ${status ?? '?'} for ${error.requestOptions.uri}',
    DioExceptionType.cancel =>
      'Request to ${error.requestOptions.uri} was cancelled',
    _ => 'Network error calling ${error.requestOptions.uri}: ${error.message}',
  };
  return NetworkFailure(reason, statusCode: status);
}

/// Streaming variant of [networkFailureFromDio]: with
/// `ResponseType.stream` an error response's body arrives as an unread
/// [ResponseBody], so the provider's actual error message (e.g. Anthropic's
/// `invalid_request_error` text) would otherwise be dropped on the floor.
/// Drains it and appends the message to the failure reason.
Future<NetworkFailure> networkFailureFromStreamingDio(
  DioException error,
) async {
  final failure = networkFailureFromDio(error);
  final detail = await _readErrorBody(error.response?.data);
  if (detail == null) return failure;
  return NetworkFailure(
    '${failure.message} — $detail',
    statusCode: failure.statusCode,
  );
}

Future<String?> _readErrorBody(Object? data) async {
  String? raw;
  if (data is ResponseBody) {
    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in data.stream) {
        builder.add(chunk);
        if (builder.length > 64 * 1024) break;
      }
      raw = utf8.decode(builder.takeBytes(), allowMalformed: true);
    } catch (_) {
      return null;
    }
  } else if (data is String) {
    raw = data;
  } else if (data is Map) {
    raw = jsonEncode(data);
  }
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final err = decoded['error'];
      final message = err is Map ? err['message'] : decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
  } catch (_) {}
  final trimmed = raw.trim();
  return trimmed.length > 500 ? trimmed.substring(0, 500) : trimmed;
}
