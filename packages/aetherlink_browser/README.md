# aetherlink_browser

Aetherlink 内置浏览器能力包（M1，设计稿 `docs/design/browser-tool-design.md`）：
`HeadlessInAppWebView` 单页会话 —— 导航 / Readability 正文提取 / 截图，
外加导航前 SSRF URL 策略与互斥串行的会话管理。

## 公共 API

```dart
final manager = BrowserSessionManager(factory: HeadlessBrowserSession.new);

final result = await manager.run((session) async {
  final page = await session.open('https://example.com');
  final text = await session.readText();
  final jpeg = await session.snapshot();
  return (page, text, jpeg);
});

await manager.closeAll(); // App 退出时释放 WebView
```

- **只读三件套**：`open` / `readText` / `snapshot`；click/input 留 M4。
- **会话模型（§16）**：首版单 WebView 共享 + 互斥队列 + 空闲超时释放；
  `run(sessionId: ...)` 参数保留为多实例升级口，当前忽略。
- **安全（§15.2）**：`UrlPolicy` 协议白名单（仅 http/https）+ DNS 解析后
  校验实际 IP 不落内网/环回/链路本地/元数据段；重定向逐跳复检挂在
  `shouldOverrideUrlLoading`。间接提示注入的"不可信内容包裹"由主工程
  接入层负责（§15.3）。
- **超时（§19.2）**：导航 30s，超时截停并抛 `navigationTimeout`（会话
  保留，页面部分可读）；JS 10s；连续 2 次超时类失败自动 dispose 重建
  WebView。
- **截图（§17.2）**：JPEG 压缩；`maxWidth` 临时缩视口后截图，
  `fullPage` 按内容高截整页（封顶 6 倍宽）。

## 依赖方向

```
主工程 mcp_tools → aetherlink_browser → flutter_inappwebview
```

包不 import 主工程任何代码；`security/`、`session/page_load.dart`、
`session_manager.dart` 为纯 Dart，`flutter test` 直接可跑。

## 测试

```
flutter test packages/aetherlink_browser
```

WebView 真实行为（渲染/截图）需真机验证，将随 M2 主工程接入联调
（对齐 aetherlink_saf/terminal 惯例，包内不建 example 工程）。
