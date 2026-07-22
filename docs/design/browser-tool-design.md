# 内置浏览器模块 `aetherlink_browser` 设计

> 状态：定稿（初稿 + 网络研究补充）
> 对标：Claude Code `WebBrowserTool`
> 定位：`packages/aetherlink_browser` 本地包 + 主工程 `lib/shared/mcp_tools/` 薄接入层
> 技术选型：**flutter_inappwebview `HeadlessInAppWebView`**（见 §10 研究结论）

## 1. 背景与目标

### 现状缺口
智能体当前只有纯文本抓取工具：`@aether/fetch`（HTTP GET → HTML 转
Markdown）、`@aether/searxng` / `@aether/metaso` / `@aether/grok-search`
（搜索）。它们抓不到：

- 需要登录 / Cookie / 会话的页面；
- 前端 JS 渲染（SPA）后才有内容的页面；
- 需要点击、翻页、展开、填表才能到达的内容；
- 需要"看"页面视觉状态的场景（截图喂多模态）。

这是纯 `HttpClient` 抓取的天花板，也是 CC `WebBrowserTool` 补的能力。

### 目标
- 在移动端提供**交互式、带 JS 渲染**的网页能力，作为内置工具；
- 复用现有 `packages/` 本地包分层惯例（对标 `aetherlink_terminal`、
  `aetherlink_saf`）：能力沉到包里，schema / 审批 / 事件落库留在主工程；
- 分两步落地：**只读优先**（open/read/snapshot）先上，交互类（click/
  input）随后。

### 非目标
- 不做无头（真·headless）浏览器进程（移动端不现实）；用隐藏/离屏 WebView；
- 不在包内做工具 schema、权限审批、事件流——那些是主工程 mcp_tools 层职责；
- 首版不做多标签页并发、下载管理、文件上传。

## 2. 为什么做成 `packages/` 本地包

与现有本地包判据一致：

| 判据 | aetherlink_terminal | aetherlink_saf | **aetherlink_browser** |
| --- | --- | --- | --- |
| 有重原生依赖 | PRoot jniLibs + JNI | Android SAF 原生桥 | WebView（flutter_inappwebview 原生绑定） |
| 能力域自洽 | PTY 会话生命周期 | 文件树读写 | 页面会话生命周期 |
| 主工程只消费接口 | terminal_execute 薄接入 | 工作区后端消费 | browser_* 薄接入 |
| 隔离第三方依赖 | 是 | 是 | 是（inappwebview 不污染主 pubspec） |

## 3. 分层与目录

```
packages/aetherlink_browser/
  pubspec.yaml                    # 依赖 flutter_inappwebview
  lib/
    aetherlink_browser.dart       # 公共 Dart API（library 门面）
    src/
      browser_session.dart        # 单页会话：导航/读取/截图/交互
      browser_manager.dart        # 会话池：按 sessionId 复用 WebView
      models.dart                 # 结果/错误/选项数据类（纯 Dart）
  android/                        # inappwebview 已含原生，通常无需自写
  README.md

lib/shared/mcp_tools/browser/     # 主工程薄接入层
  browser_tools.dart              # 工具 schema + 路由 + 结果封装
  browser_tool_catalog.dart       # 目录条目（settings 列表用）
```

包只暴露纯 Dart API，例如：

```dart
abstract class BrowserSession {
  Future<PageLoadResult> open(String url, {Duration? timeout});
  Future<String> readText({String? selector});     // 提取正文/元素文本
  Future<String> readDomOutline();                  // 结构化 DOM 摘要
  Future<Uint8List> snapshot({bool fullPage});      // 截图 PNG 字节
  Future<void> click({String? selector, int? x, int? y});
  Future<void> input({required String selector, required String text});
  Future<PageLoadResult> waitForLoad({Duration? timeout});
  Future<void> close();
}

class AetherlinkBrowser {
  static Future<BrowserSession> openSession({String? id});
  static BrowserSession? session(String id);
  static Future<void> closeAll();
}
```

## 4. 工具集（模型可见）

阶段一（只读）：

| 工具 | 参数 | 返回 | 说明 |
| --- | --- | --- | --- |
| `browser_open` | `url`, `session?`, `timeout?` | 页面标题 + 最终 URL + 首屏正文摘要 | 打开并等待渲染；复用/新建会话 |
| `browser_read` | `session?`, `selector?`, `format?(text/markdown/outline)` | 页面/元素内容 | 当前页提取；无 selector 取正文 |
| `browser_snapshot` | `session?`, `full_page?` | 图片（多模态 content） | 截图供模型"看" |

阶段二（交互）：

| 工具 | 参数 | 说明 |
| --- | --- | --- |
| `browser_click` | `session?`, `selector`/`x,y` | 点击后自动等待可能的导航 |
| `browser_input` | `session?`, `selector`, `text`, `submit?` | 填表；submit 可回车提交 |
| `browser_close` | `session?` | 关闭会话释放 WebView |

会话态：一个隐藏 WebView 实例作为会话，多次调用复用同一页面（登录态、
表单填写跨调用保持）。默认单会话 `default`，`session` 参数支持多页面。

## 5. 数据流

```
模型 → browser_open(url)
  → 主工程 browser_tools.dart 校验参数 + 审批门
  → AetherlinkBrowser.openSession().open(url)
     → 包内：离屏 InAppWebView 导航 + 等待 onLoadStop / JS ready
  → 提取标题 + 正文摘要（包内 JS 注入 document 提取）
  → McpToolResult（文本；snapshot 时为图片 content）
  → 事件流落 ToolCallEvent（主工程）
```

截图回传：`browser_snapshot` 返回 PNG 字节 → 主工程封装为多模态图片
content（复用现有工具图片返回通道，若无则新增）。

## 6. 工具分组与权限

- 归入 `AgentToolGroup.webSearch`（与 fetch/搜索同组），或新增
  `AgentToolGroup.browser`（待定，见开放问题）；
- 只读三件套（open/read/snapshot）风险低，走普通审批；
- 交互类（click/input）可能触发登录/提交，接现有 approval gate，
  Auto 模式默认需确认；
- Ask/Plan 只读模式：只暴露 open/read/snapshot，隐藏 click/input。

## 7. 移动端要处理的现实问题（含研究结论）

1. **离屏渲染 → 用官方 `HeadlessInAppWebView`**：无需自己挂 Offstage/0
   尺寸容器。它专为"不挂到 widget 树、在后台运行 WebView"设计，与
   `InAppWebView` 同样的 settings/events，用 `InAppWebViewController`
   控制。默认初始尺寸为设备屏幕大小（`Size(-1,-1)`），可用
   `initialSize: Size(1024, 768)` 固定，`getSize/setSize` 动态改。
   **必须** `dispose()` 释放。
2. **等待渲染完成**：`onLoadStop` + 轮询 `document.readyState==='complete'`；
   SPA 再补一层"等待选择器出现 / 网络空闲 / 固定短延时"三选一策略，
   全部带超时。CDP（见 §10）可用 `Page.loadEventFired` 更精确，但首版
   用 onLoadStop + readyState 足够。
3. **正文提取 → 注入 Mozilla Readability.js**：`new Readability(document)
   .parse()` 返回 `title/content/textContent/excerpt`，是业界标准（Firefox
   Reader View 同款）。作为包内资产打包，`evaluateJavascript` 注入。
   取不到正文时回退 `document.body.innerText`。大页面截断 + 分块（对齐
   fetch 的 `start_index`/`max_length`）。
4. **截图 → `controller.takeScreenshot()`** 返回 PNG `Uint8List`，可传
   `ScreenshotConfiguration`（压缩质量、区域）。首版限 DPR/宽度、jpeg
   压缩控体积。
5. **后台限制**：Android WebView 在应用后台可能被限流。首版约束"工具执行
   期间应用在前台/任务运行态"，长时页面加超时。真需要后台可对标
   `aetherlink_terminal` 的 ForegroundService（列为后续）。
6. **生命周期泄漏**：会话池持有 `HeadlessInAppWebView`，`browser_close`
   或空闲超时（如 5 分钟）自动 `dispose`；App 退出时 `closeAll`。
7. **安全**：`initialSettings` 关闭不必要能力——`javaScriptCanOpenWindows
   Automatically=false`、限制/拦截下载、按需隔离 `allowFileAccess*`；
   Cookie 由 `CookieManager` 管理，会话级；不落敏感数据到事件流。
8. **权限**：AndroidManifest 仅需 INTERNET（主工程已有）。inappwebview
   要求 `compileSdk>=34`、`minSdk>=19`、AGP>=7.3——需核对主工程当前值
   （见 §10 待核对项）。

## 8. 里程碑

- **M1 包骨架**：`aetherlink_browser` 建包 + 会话/管理器 + open/read/snapshot；example 手测。
- **M2 主工程接入**：browser_tools.dart schema + 路由 + 审批 + 事件；截图多模态回传。
- **M3 交互**：click/input/close + 等待导航策略。
- **M4 打磨**：会话回收、超时、正文提取质量、截图压缩、后台策略。

## 9. 开放问题（研究后结论）

1. **离屏/截图/JS → 已解决**：官方 `HeadlessInAppWebView` 直接支持后台
   运行、`takeScreenshot`、`evaluateJavascript`，无需自研离屏。
2. **SPA 渲染判定 → 已定方案**：onLoadStop + `document.readyState` 轮询
   + 可选选择器/延时兜底（§7.2）。
3. **正文提取 → 用 Readability.js**（§7.3），回退 innerText。
4. **与 fetch 的边界 → 写进工具描述给模型**：静态/无需登录/无 JS 渲染优先
   `@aether/fetch`（轻、快、无 WebView 开销）；需要登录/JS 渲染/交互/"看
   页面"才用 `browser_*`。避免模型无脑用重工具。
5. **工具分组 → 建议新增 `AgentToolGroup.browser`**（当前枚举：
   `fileEditor, terminal, webSearch, knowledgeBase, skills`）。理由：浏览器
   有独立风险面（交互、登录），单独分组便于 profile 精细授权；只读子集
   也可考虑并入 webSearch，**留给用户拍板**（见 §11）。
6. **截图多模态回传 → 有硬缺口，需先补主工程**：现有
   `McpToolResult(this.text, {isError})` **只支持纯文本**（
   `lib/shared/domain/mcp_tool.dart`），没有图片 content 通道。要接
   `browser_snapshot` 需先给工具结果加图片载荷，并打通 LLM gateway 的多
   模态消息。**这是阶段一的前置改造**，也可先把 snapshot 挪到阶段二、
   首版只做 open/read（纯文本）降低风险。
7. **ForegroundService → 首版不做**，约束前台执行；后续按需对标 terminal。
8. **平台**：`HeadlessInAppWebView` 支持 Android/iOS/macOS/Windows/Web，
   包保持平台无关；当前只在 Android 验证，其他平台顺带可用。

## 10. 研究结论与依赖核对

**选型：flutter_inappwebview 6.1.5（stable，1.12M 下载 / 2.83k likes）**
- `HeadlessInAppWebView`：后台无 UI 运行 WebView，官方支持
  Android/iOS/macOS/Windows/Web；同 `InAppWebView` 的 settings/events。
- 关键 API：`evaluateJavascript`、`takeScreenshot(ScreenshotConfiguration)`、
  `onLoadStop`、`onConsoleMessage`、`getSize/setSize`、`CookieManager`。
- 支持 Chrome DevTools Protocol（CDP），后续可做更精确的加载/网络控制。
- **拒绝的替代方案**：Chrome Custom Tabs / `webview_flutter` 官方包——
  Custom Tabs 是给用户看的浏览器，无法程序化提取内容/截图；
  `webview_flutter` 无 headless、JS 交互/截图能力弱于 inappwebview。

**依赖门槛核对（主工程已满足）**：
| 要求 | inappwebview | 主工程现状 | 结论 |
| --- | --- | --- | --- |
| AGP | ≥7.3.0 | 8.11.1 | ✅ |
| compileSdk | ≥34 | flutter.compileSdkVersion（3.44→35） | ✅ |
| minSdk | ≥19 | flutter.minSdkVersion | ✅（核对 ≥19） |
| Flutter | ≥3.24.0 | 3.44.x | ✅ |
| Dart | ^3.5.0 | 3.12.x | ✅ |

**供应链**：优先锁定 6.1.5（发布已久、稳定），不用 6.2.0-beta。

## 11. 需要用户拍板的决策

1. **首版范围**：A) open+read（纯文本，零多模态改造，最快落地）；
   B) open+read+snapshot（需先补 `McpToolResult` 图片通道，见 §9.6）。
2. **工具分组**：新增 `AgentToolGroup.browser` 独立组，还是并入
   `webSearch`？
3. **交互类（click/input）**：本轮做还是先只读、下一轮再做？
