/// Placeholder for the shared dio instance and interceptors.
///
/// The real client — auth/logging/retry interceptors plus a handwritten SSE
/// parser, collapsed behind a single provider factory (see ADR-0004) — lands in
/// milestone M2. No dio instance is created yet; this library only fixes the
/// network module's location per `docs/PROJECT_STRUCTURE.md`.
library;
