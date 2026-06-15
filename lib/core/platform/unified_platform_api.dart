/// Cross-platform capability surface (interface only).
///
/// Mirrors the original Aetherlink `UnifiedPlatformAPI` (see
/// `docs/ARCHITECTURE.md` §6): a single abstraction over filesystem,
/// notifications, clipboard, device, and the platform-specific window/camera
/// APIs. Concrete implementations are provided per platform and injected via
/// Riverpod in milestone M3; the sub-API contracts are intentionally left as a
/// TODO until then.
abstract interface class UnifiedPlatformApi {
  // TODO(M3): expose fileSystem / notifications / clipboard / device /
  //   window? (desktop) / camera? (mobile) sub-APIs once their contracts land.
}
