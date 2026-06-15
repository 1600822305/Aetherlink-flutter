# 统筹大脑 · 项目总纲（先读这份）

> **这是整个项目的唯一入口文档。** 新会话 / 新人 / 接手的 AI，先把这份从头读完，就知道「这是什么、为什么这么做、现在到哪了、接下来干什么」。读完再按 §8 的文档地图深入。
>
> 一句话定位：**把 React 版 Aetherlink 重写成 Flutter 版，借这次迁移把原项目乱七八糟的结构彻底治好。**

---

## 1. 这是什么项目

- **Aetherlink**：一个 AI / LLM 聊天客户端（多模型、多供应商、话题/助手、流式对话、思考块、知识库、MCP 等）。
- **原项目（要迁走的）**：`https://github.com/1600822305/Aetherlink`
  技术栈：React 19 + MUI v7 + @emotion + tailwind，跑在 Capacitor 8（移动 webview）+ Tauri 2（桌面 webview）上。状态用 Redux Toolkit（14 slice）+ zustand + signals，数据用 Dexie/IndexedDB，LLM 走 Vercel AI SDK。规模：**972 个 TS 文件 / 207 个目录**。
- **新项目（本仓库，要迁到的）**：`https://github.com/1600822305/Aetherlink-flutter`
  技术栈：Flutter（Dart）。目前 `lib/` 还是 `flutter create` 的默认计数器骨架，**业务代码一行没写**，只有 `docs/` 这套设计文档。

---

## 2. 为什么要迁（前因 —— 两个核心动机）

### 动机 A：干掉 webview 的滚动天花板
原项目是「网页套壳」（Capacitor/Tauri 都是 webview 宿主）。即便前端已优化到极限（120fps），webview 的滚动丝滑度仍有**硬上限**——这是壳的天花板，不是代码不行。换 Flutter 原生 `ScrollView` 直接拿掉这个限制。

### 动机 B：根治原项目的结构腐烂（**迁移的重点**）
原项目结构是典型的「能跑但会烂」，证据（源码扫描得到的真实数字）：

| 病灶 | 证据 |
| --- | --- |
| 按文件类型分目录（type-first） | `components/ hooks/ utils/ services/ store/` 平铺，一个「聊天」功能摊到 5+ 个目录 |
| 重复抽象层（没有唯一的家） | `src/utils`(9) **与** `src/shared/utils`(63) 并存；`hooks`/`config`/`types` 同样双份 |
| God-folder | `src/shared/services` = **245 个文件** |
| 同一概念散落 | provider 逻辑散在 7 处，含**两个** `ProviderFactory` |
| 体量失控 | 972 文件 / 207 目录，无边界约束 |

> **结论：迁 Flutter 是重订结构的唯一窗口。** 这套文档的核心使命，就是把「干净的结构」立成**死规矩（靠工具强制，不靠自觉）**，别让新项目又烂成老样子。

### 一个已经关掉的问题：UI 还原度
曾经担心「Flutter 复刻不出 MUI 的观感」。已用三页验证否决了这个担心：关于页 ~95%、模型设置 ~97%、聊天主界面（气泡/思考块/输入框）已逐像素对齐。动态渲染（markdown/代码高亮/LaTeX）用户在别的 Flutter 项目实测正常。**所以 UI 不是风险，剩下的是工作量。** 这一条不用再纠结。

---

## 3. 决定怎么迁（核心决策 + 理由）

| 决策 | 选择 | 为什么（详见） |
| --- | --- | --- |
| 整体结构 | **单包 feature-first**（不上 monorepo） | 适合单人/小团队；边界靠 `custom_lint` 卡。`adr/0001` |
| 分层 | Clean Architecture：`presentation → application → domain ← data` | UI 与业务解耦，domain 纯 Dart 可单测。`ARCHITECTURE.md` |
| 状态 | **Riverpod** | 与原 Redux slice 近乎一一对应，兼当 DI。`adr/0002` |
| 持久化 | **Drift / SQLite** | 数据是 topic→message→block 的关系结构。`adr/0003` |
| 网络/LLM | **dio + 自写 SSE**，收口单一 ProviderFactory | 修掉原项目两个 factory 的病；删 cors-proxy。`adr/0004` |
| 模型 | **freezed**（先行） | 模型是所有层的契约，第一步先定死。`DOMAIN_MODEL.md` |
| 迁移方式 | **按行为重写，不逐行抄** + 补丁三分类 | 抄会把框架税和 bug 一起搬过来。`MIGRATION.md` |
| 桌面端 | **暂时搁置**，但架构设计成 UI 无关，以后随时并入 | `ARCHITECTURE.md` §7 |

**两个贯穿全程的原则：**
1. **领域模型先行**：动 db/网络/UI 之前，先把核心实体用纯 Dart（freezed）定死。
2. **死规矩靠工具**：目录/依赖边界由 `analysis_options.yaml` + `custom_lint` 在分析期强制，CI 卡住，不靠人记。

**补丁三分类**（迁移时每段「打补丁」逻辑先归类再处理）：
- ① 框架税 / webview·Redux·Dexie 的 workaround → **扔**（Flutter 里没有对应物）。
- ② 生产踩出来的业务修复 → **留**，但干净重写 + 写成回归测试（别丢这些「用 bug 换来的」修复）。
- ③ 纯技术债 / 真 bug → **修**。

---

## 4. 现在做到哪了（当前状态）

- ✅ **设计文档已写齐并合并**（PR #1、#2）：结构/架构/迁移/模型/路线图/约定/测试/ADR 全在 `docs/`。
- ✅ 结构强度已拍板：单包 feature-first + lint 强制边界。
- ⬜ **代码：尚未开始。** `lib/` 还是默认骨架。
- ⏭ **下一步 = M0**：搭 feature-first 骨架（空目录 + 依赖 + lint 边界配置 + 最小闭环），再把核心 freezed 领域模型翻出来。

> 进度的**实时看板**在 `ROADMAP.md` 末尾（M0~M5 + 数据迁移，⬜/✅）。**每完成一个里程碑，就去把那张表对应行打勾**——它是「做到哪了」的唯一事实来源。

---

## 5. 接下来按什么顺序做（自底向上，UI 最后）

```
M0  领域模型 + 骨架   freezed 模型；feature-first 目录 + 依赖 + lint 边界
M1  数据层           Drift schema/DAO/repository 实现 + 老数据迁移方案
M2  网络/LLM 层       dio + SSE + 各 provider client（收口单一 factory）
M3  平台抽象层        UnifiedPlatformApi + 各平台插件实现
M4  移动端 UI         逐页复刻（已验证可 1:1）
M5  桌面端 UI         复用下层，只做桌面 shell
   ┊
  老数据迁移          IndexedDB → SQLite 一次性导入
```
每个里程碑的**验收标准**见 `ROADMAP.md`。分层细则文档（state/data/network/platform）**跟着对应里程碑一起写**，不提前空谈。

---

## 6. 关键约束 / 雷区（别犯）

- **不逐行抄原项目**——把它当规格说明（spec），按行为重写；每个补丁先过三分类。
- **边界靠 lint 强制**：presentation✗→data、domain✗→框架/IO、feature A✗→feature B 内部、core/shared✗→features。
- **core/shared 有准入门槛**：只有「≥2 feature 用 且 无 feature 专属逻辑」才准进，否则留在 feature 里（防 God-folder 重演）。
- **一个概念只有一个家（SSOT）**：不准再出现重复抽象层 / 两个 factory。
- **禁止垃圾桶目录名**：`common` / `misc` / `helpers` / `utils2`。
- **桌面端先不管**，但任何设计都要保持 UI 无关，方便以后并入。
- **动态渲染不用纠结**，已确认可行。

---

## 7. 给「下一个会话」的开场指令（可直接粘）

> 读 `1600822305/Aetherlink-flutter` 仓库的 `docs/CONTEXT.md` 了解全部前因后果，然后看 `docs/ROADMAP.md` 的进度看板，从当前**未完成的最靠前里程碑**接着做。严格遵守 `docs/PROJECT_STRUCTURE.md` 和 `docs/CONVENTIONS.md` 的死规矩。

（如果只是要「搭骨架」这一步，另有一份现成的详细提示词可直接用。）

---

## 8. 文档地图（读完本页后按需深入）

| 文档 | 干什么 | 何时读 |
| --- | --- | --- |
| **CONTEXT.md**（本页） | 总纲 / 前因后果 / 当前状态 / 下一步 | **最先读** |
| `PROJECT_STRUCTURE.md` | 死规矩：目录、依赖边界、准入门槛、决策树、护栏 | 写任何代码前 |
| `ARCHITECTURE.md` | 分层、选型、流式聊天数据流、平台抽象、双 UI | 理解整体设计 |
| `DOMAIN_MODEL.md` | 模型先行、TS→freezed 映射、MessageBlock 14 联合 | 做 M0 |
| `MIGRATION.md` | 按行为重写、补丁三分类、对拍、迁移顺序、数据迁移 | 每迁一个模块 |
| `CONVENTIONS.md` | 命名、lint/边界配置、codegen、commit/PR、DoD | 随用随查 |
| `TESTING.md` | 测试金字塔、对拍、②类补丁→测试模板、CI | 写测试时 |
| `ROADMAP.md` | M0~M5 里程碑 + 验收 + **进度看板** | 看进度 / 每完成一步打勾 |
| `adr/` | 选型背后的「为什么」（Riverpod/Drift/dio/单包） | 想质疑某个选型时 |

---

## 9. 关键链接与坐标

- 新仓库（本项目）：https://github.com/1600822305/Aetherlink-flutter
- 原仓库（迁移源）：https://github.com/1600822305/Aetherlink
- 文档 PR：#1（结构/架构/迁移/模型/路线图）、#2（约定/测试/ADR）—— 均已合并。
- 默认分支 `main`；新工作一律开分支 + PR，不直接推 main。
