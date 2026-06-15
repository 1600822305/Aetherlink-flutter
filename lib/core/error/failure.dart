/// Base type for recoverable, domain-level failures.
///
/// Concrete failures (network, persistence, validation, …) will extend this
/// sealed hierarchy in later milestones. The `data` layer maps exceptions onto
/// these, and the app returns them via [Result] instead of throwing for
/// expected error paths (see `docs/ARCHITECTURE.md`).
sealed class Failure {
  const Failure(this.message);

  final String message;
}

/// A failure while talking to a remote provider — transport error, timeout or
/// non-2xx HTTP status. Pure Dart; the dio-specific mapping that produces it
/// lives in `network_error_mapper.dart`.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {this.statusCode});

  /// HTTP status code when the failure came from a server response.
  final int? statusCode;
}
