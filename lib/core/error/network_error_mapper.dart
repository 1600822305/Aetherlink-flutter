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
