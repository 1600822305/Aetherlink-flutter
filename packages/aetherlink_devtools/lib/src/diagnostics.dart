/// Host-injected context for AI-diagnostic exports.
///
/// The dependency-free `aetherlink_devtools` package can't read device/env info
/// itself, so the app sets [contextProvider] once at startup (with a device +
/// environment summary). The Console panel's "复制为 AI 诊断" prepends whatever it
/// returns, giving the AI both the device context and the recent log tail.
class DevToolsDiagnostics {
  DevToolsDiagnostics._();

  /// Returns an app-supplied context block (device / OS / build mode / …) to
  /// prepend to AI-diagnostic copies, or null when the host hasn't wired it.
  static String Function()? contextProvider;
}
