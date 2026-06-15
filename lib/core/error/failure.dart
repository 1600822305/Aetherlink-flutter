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
