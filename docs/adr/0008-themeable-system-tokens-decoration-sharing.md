# ADR-0008：可主题化系统——主题即数据（token 化）、装饰层自由配图、AI 生成、资源包分享

- **状态**：Accepted（**新决策**，不推翻任何既有 ADR。建立 M4 的主题地基；复用既有接缝：持久化走 **ADR-0003**（Drift），AI 生成走 **ADR-0006** 的 `LlmGateway`，资源落盘/分享走 **ADR-0007** 的 `FileSystemApi`/`ShareApi`/`ClipboardApi`。引入一个**只留接口、暂不实现**的新 port `ImageGenerationApi`，沿用 ADR-0007 的「留缝不实现」手法。`ARCHITECTURE.md` 此前没写主题层，本 ADR 即其首次定调。）
- **日期**：2026-06-15
- **决策者**：Kenneth + 架构师会话

## 背景（Context）

需求来自 Kenneth：希望桌面端能像 **Cherry Studio** 那样让用户**自定义主题风格**，并进一步要：① **AI 能生成主题**；② **用户之间能分享主题**；③ 主题里能**混入图片**（如塞一个卡通人物），且希望是**随意配图**而非固定位置；④ 生图功能**只要把接口搞出来**，暂不需要真实现。移动端要同样能用。

约束与前情：

- **离开 webview 是本迁移的核心动机之一**（`CONTEXT.md` 动机 A：webview 滚动天花板）。Cherry Studio 是 Electron（网页壳），它能「改 CSS」是因为 CSS 引擎是壳白送的——用户写的 CSS 直接喂给 DOM 重绘。**Flutter 没有 DOM / 没有 CSS 引擎**，渲染走 widget 树。照搬「注入任意 CSS」唯一办法是把界面塞进 `WebView` 渲染，**等于把刚甩掉的 webview 请回来**，自我打脸。
- 已落地的接缝可直接复用：**M1** 的 Drift 持久化、**M2** 的 `LlmGateway`（schema 约束下让 LLM 吐 JSON）、**M3** 的 `FileSystemApi`/`ShareApi`/`ClipboardApi`（资源落盘 + 主题搬运）。
- 死规矩不变：分层 `presentation → application → domain ← data`；`domain` 纯 Dart（过 `import_boundaries_test`）；不引重复抽象、重复优于错误抽象（ADR-0006 精神）。

核心张力：「让用户/AI 自由定制观感」很容易滑向「让主题任意改 CSS / 任意重排布局」——那既要 webview，又会把 app 改崩，还让 AI 输出与分享内容**不可校验、不可信**。本 ADR 要在「自由度」和「不重造一个布局/CSS 引擎」之间划死那条线。

## 选项（Options）

**A. 自定义机制：**
1. **raw CSS 注入**（照搬 CS）：要么塞 `WebView`（回退 webview，违背动机 A），要么自建 CSS 解析。AI 输出 = 无边界字符串，无法校验、易改崩、有注入风险。
2. **token 化：主题 = 一份有 schema 的数据**（`ThemeSpec`）→ 映射成 `ThemeData` + `ThemeExtension`。用户改主题 = 改数据（UI 调 or 导入文件），Riverpod 热切换。
3. **预设-only**：只给固定几套主题，不让用户改。
4. **自写 styling-DSL + 解释器**：等于重造半个 CSS 引擎。

**B. 配图方式：**
1. **固定 slot**：主题只能填预定义的几个图片位（背景、mascot…），位置固定。
2. **装饰层（受控自由）**：一串「定位图片元素」叠加在几个**命名 surface** 上，相对坐标 + 锚点，自由摆放/缩放/旋转/调透明度/排 z 序，但**只是叠加层**、不参与功能布局。
3. **任意重排功能布局**：让主题挪发送键、重构消息列表等——重造布局引擎 + 把 app 用崩。

**C. AI 生成：**
1. 现在就做**生图实现**（接 DALL·E/SD/Gemini 图像）。
2. **只把接口（port）搞出来、不实现**：定 `ImageGenerationApi` + 占位 provider，以后接 impl 即用。
3. 完全不碰生成相关。

**D. 分享载体：**
1. **单 JSON**（图片 base64 内嵌）：大图撑爆 JSON，体积/性能差。
2. **资源包 zip**（`manifest.json + assets/<hash>.ext`）：无图主题可退化成单 JSON。

## 决策（Decision）

选 **A2 + B2 + C2 + D2**。一句话：**主题是一份可校验、可分享、可被 AI 生成的结构化数据；图片以「受控自由的装饰叠加层」混入；生图只留接口不实现；带图主题打包成资源包分享。**

### 划线规则一：主题即数据（token 化），不是代码/CSS
- `ThemeSpec`（freezed，**纯 Dart**）是唯一真相：配色角色（seed / surface / 文本 / 气泡.user / 气泡.ai / 链接 / 代码块配色…）、字体（family/scale）、形状（圆角）、密度/间距、`schemaVersion`。
- `ThemeSpec → ThemeData + ThemeExtension<T>` 是一个**纯映射**（自定义组件样式挂在 `ThemeExtension` 上）。该映射 import Flutter，属 **presentation 侧**，不污染 domain。
- 运行时用 Riverpod `themeSpecProvider` 持有当前主题、热切换；已装主题用 **M1 Drift** 持久化。
- **不许**任何「主题字符串 → 运行时解释样式」的 CSS/DSL 通道；主题的全部表达力 = 我们开放的 token 集合。要更自由就**加 token**，不开 CSS 口子。

### 划线规则二：自由配图 = 装饰层（overlay），功能布局不可动
- 「随意配图」建模成**装饰层**：主题持有一串元素 `{asset, surface, 位置(相对x,y), 尺寸, 锚点, 旋转, 透明度, 混合模式, z序}`。
- `surface` = 少数**命名画布**（如 `chatBackground`、`appScaffold`、`emptyState`…）；坐标用**相对值 + 锚点**（响应式，跨设备不错位），并**夹紧到安全区**。
- 装饰层默认**点击穿透**（不吃手势）、**不参与功能布局测量**——它只是叠加在功能 UI 之上/之下的图层。摆崩了只是难看，**点不坏功能**。
- **红线**：主题**绝不能**重排/重构功能性 widget（挪按钮、改消息列表结构）。**叠加图层随意配，功能布局不许动**——这条就是「自由」与「重造布局引擎」的分水岭。

### 划线规则三：分层与放置（接缝复用，别另起炉灶）
- `ThemeSpec` + 装饰层模型 = **纯 Dart domain 值类型**，零 Flutter import，过 `import_boundaries_test`。
- **资源字节不进 `ThemeSpec`**：`ThemeSpec` 只存**引用（内容哈希）**；图片字节落到一个**内容寻址资源库**（哈希→文件，走 **M3 `FileSystemApi`**），data 层负责。自带去重 + 完整性校验。
- **AI 生成**走 application 用例：组 prompt（内嵌 `ThemeSpec` 的 JSON schema + 用户自然语言）→ **M2 `LlmGateway`** → 解析 → **按 schema 校验/夹紧** → 套用前给预览。输出被 schema 框死，AI 改不崩布局、注入不了恶意样式。
- 主题这一摊（domain 模型 + application 用例 + data 仓库/资源库 + presentation 编辑器/映射）建议收成一个 feature 垂直（如 `features/theming/`）；app 根（composition root）watch 它暴露的 `ThemeData`/装饰层 provider 装配 `MaterialApp` 与 app shell。**精确落点交 `PROJECT_STRUCTURE.md` + M4.0 交接细化**，本 ADR 只钉分层与依赖方向。

### 划线规则四：生图只留接口、不实现
- 定 `ImageGenerationApi`（**纯 Dart port**，中性 DTO：`prompt(+尺寸/风格) → 图片字节 / asset 引用`）+ 一个 Riverpod provider。
- **M4 阶段挂一个「未实现」占位 impl**（调用即抛 `UnsupportedError` 或返回明确的「未配置」结果），UI 对此能力做优雅降级（按钮置灰/提示未启用）。
- 以后要接真生图（DALL·E/SD/Gemini 图像…）= 写一个 impl 实现该 port + 改 provider 绑定，**上层一行不动**（同 ADR-0007 换插件的套路）。接缝今天留好，不拖 M4 进度。

### 划线规则五：分享 = 资源包
- 可分享主题打包成 `.aethertheme`（zip：`manifest.json` + `assets/<hash>.<ext>`）；**无图主题可退化成单个 JSON**。
- 导出 = 打包（走 **M3 `ShareApi`**，或复制 JSON 走 `ClipboardApi`）；导入 = 解包 → 校验 `manifest`（含 `schemaVersion`）→ 逐图核对哈希 → 入库。
- 后续做「社区主题库」只是再加一个 JSON 索引源，载体结构不变。

## 理由（Rationale）

- **token 化是唯一同时满足全部诉求的方案**：不要 webview（A2 不需要 DOM/CSS 引擎）、AI 能安全生成（schema 约束下 LLM 吐 JSON，比让 AI 写无边界 CSS 既容易又可校验）、能分享（数据/小包天然可搬）、移动桌面共用（纯数据 + 纯映射，跟 M4/M5 只分叉 presentation 同理）。raw CSS（A1）违背前两条，预设-only（A3）砍掉 AI 生成与分享，自写 DSL（A4）是重造 CSS 引擎。
- **装饰层给足自由又不失控**：Figma 图层 / OBS 叠加 / 游戏 HUD 编辑器都是「命名画布上的一串定位精灵」，这就是「卡通人物想摆哪摆哪」的可实现、可分享、可校验形态，且因为是 overlay、点击穿透、不参与布局测量，**改坏了也点不坏功能**。把「自由」限定在装饰层、把「功能布局」锁死，是不滑向 webview/布局引擎的关键。
- **复用既有接缝、不另起炉灶**：持久化（M1）、AI（M2 `LlmGateway`）、资源落盘与搬运（M3 文件/分享/剪贴板）已就位，主题系统是把它们串起来，而不是新造基础设施——符合「重复优于错误抽象、但也别重复造轮子」。
- **生图留缝不实现**：满足「先把接口搞出来」的诉求，零实现成本，且明确这是 M2/M3 之外的后续能力，不浮夸承诺、不拖当前里程碑。

## 后果（Consequences）

- **正面**：主题=可校验数据，AI 生成与用户分享都落在「结构化、可校验、可信化」的轨道上；移动桌面共用底层；换/加 token 与换生图实现都不动上层；装饰层给到「随意配图」体验而不危及功能可用性与性能护栏。
- **负面 / 代价**：
  - 要做**装饰层编辑器 UI**（拖拽/缩放/旋转/透明度/z 序），移动端尤其费工——可分阶段，先支持「导入主题包」再做「可视化编辑器」。
  - 坐标**必须响应式**（相对 + 锚点 + 安全区夹紧），否则分享来的主题跨设备错位/挡按钮——靠「叠加层默认点击穿透 + 安全区夹紧 + 上限」对冲。
  - 多张大图叠加要管性能（缓存、降采样、解码预算）。
  - 引入资源库 + 打包/解包 + schema 版本迁移的复杂度。
- **护栏（加新东西时照这个走，别破）：**
  1. **不开 CSS/DSL 口子**：主题表达力 = 开放的 token 集合；要更自由就加 token，绝不引入「字符串→运行时解释样式」通道。
  2. **叠加图层随意配，功能布局不许动**：装饰层只能 overlay、默认点击穿透、不参与功能 widget 的测量/重排。
  3. `ThemeSpec`（domain）**只存引用、保持纯 Dart**；图片字节归 data 层 + M3 FileSystem；`ThemeSpec→ThemeData`/装饰渲染归 presentation。
  4. **导入即不可信**：解码校验确为图片、剥元数据、按 schema 夹紧未知字段；**SVG 谨慎**（可内嵌脚本——要么禁，要么 sanitize/栅格化）；图片尺寸/体积/数量/格式设硬上限。
  5. **AI 生成只产数据**：经 `LlmGateway` 拿 JSON 主题，套用前必过 schema 校验 + 预览；**生图能力只认 `ImageGenerationApi` port**，没有 impl 时优雅降级。
- **未来若要推翻的触发条件**：若产品确需「用户改任意像素/重排任意布局」成为头部卖点，且证实 token+装饰层覆盖不了——届时新开 ADR 评估「受限 styling-DSL」或局部 webview 容器，但需正面承担其性能与可信化代价（并对照动机 A）。
