/// Aetherlink 内置浏览器能力包（设计稿 docs/design/browser-tool-design.md）。
///
/// 对外只暴露纯 Dart API：会话（导航/正文提取/截图）、SSRF URL 策略、
/// 结果与错误模型。不知道主工程 McpToolResult/审批/事件流的存在。
library;

export 'src/models/browser_exception.dart';
export 'src/models/page_load_result.dart';
export 'src/security/private_networks.dart';
export 'src/security/url_policy.dart';
export 'src/session/browser_session.dart';
export 'src/session/page_load.dart' show PageLoadPoller;
export 'src/session/session_manager.dart';
export 'src/snapshot/element_target.dart';
export 'src/snapshot/screenshot.dart' show SnapshotOptions;
