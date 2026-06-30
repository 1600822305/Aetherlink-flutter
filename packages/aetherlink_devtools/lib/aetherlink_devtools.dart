/// Aetherlink in-app developer tools.
///
/// A dependency-free, self-contained Flutter package that hosts a Chrome-DevTools-
/// style panel page ([DevToolsPage]) plus a panel registry ([DevToolsRegistry])
/// the later phases (Network / Performance / Storage / Device) plug into.
///
/// P0 ships the Console panel:
/// - [ConsoleStore]: bounded ring buffer + filter, exposed via [ValueListenable]s.
/// - [DevToolsCapture]: zero-touch global hooks (FlutterError, PlatformDispatcher
///   and `debugPrint`) that feed the store without any logging calls in the app.
///
/// Typical wiring (in the host `main.dart`):
/// ```dart
/// void main() {
///   runZonedGuarded(() {
///     WidgetsFlutterBinding.ensureInitialized();
///     DevToolsCapture.install();
///     runApp(const MyApp());
///   }, DevToolsCapture.zoneErrorHandler);
/// }
/// ```
///
/// The Console panel is registered by [DevToolsCapture.install] (the single
/// startup init point); later phases append their own panels via
/// [DevToolsRegistry.register].
library;

export 'src/console/console_capture.dart' show DevToolsCapture;
export 'src/console/console_panel.dart' show ConsolePanel;
export 'src/console/console_store.dart' show ConsoleStore, ConsoleFilter;
export 'src/models/log_entry.dart' show LogEntry, LogLevel;
export 'src/network/dio_dev_interceptor.dart' show DioDevInterceptor;
export 'src/network/network_entry.dart'
    show NetworkEntry, NetworkStatus, formatDuration, formatSize;
export 'src/network/network_panel.dart' show NetworkPanel;
export 'src/network/network_store.dart' show NetworkStore, NetworkFilter;
export 'src/panel.dart' show DevToolsPanel, DevToolsRegistry;
export 'src/ui/devtools_page.dart' show DevToolsPage;
export 'src/ui/floating_button.dart'
    show DevToolsFloatingButton, DevToolsFloatingButtonHost;
