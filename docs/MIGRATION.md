# 迁移策略

> 从 `1600822305/Aetherlink`（React 19 + MUI v7 + Capacitor/Tauri）迁移到本 Flutter 项目。
> 配套：`ARCHITECTURE.md`、`DOMAIN_MODEL.md`、`PROJECT_STRUCTURE.md`、`ROADMAP.md`。

---

## 1. 第一原则：按行为重写，不逐行抄

**把 React 版当「规格说明（spec）」，不是「抄写源」。**

- 迁移的目标是**复刻行为**，不是复刻实现结构。
- 逐行抄会把原项目的**框架税**和**技术债**一起搬过来（见 §2）。
- 但「全不抄」又会丢掉原项目用 bug 换来的**业务修复**（见 §2 第②类）。
- 所以纪律是：**对每个补丁/特殊逻辑先分类，再决定扔/留/修。**

---

## 2. 补丁三分类（核心方法）

原项目里大量「打补丁式」逻辑，迁移时逐条归入三类，分别处理：

### ① 框架税 / 平台 workaround —— 扔
为了绕 React / webview / Redux / Dexie 的坑而存在，**在 Flutter 里没有对应物**：

- `cors-proxy.js`、`event-source-polyfill`（CORS / SSE 兼容）→ 原生无 CORS，删。
- 流式 re-render 节流 hack、`React.memo` 冻结、用 `@preact/signals-react` 逃离 redux → Flutter 用 `Stream` + Riverpod 选择性重建，这类 hack 消失。
- `redux-persist` rehydrate 时序补丁、IndexedDB 事务/版本怪癖兜底 → 换 Drift(SQLite) 后不存在。
- SolidJS 桥接（`bridges/SolidBridge`、`src/solid/`）→ Flutter 单一渲染，整块删。

> 这类不是业务，是框架税。抄过去是污染，**一律扔**。

### ② 业务修复 / 长出来的规则 —— 留，但「重新表达」干净
生产中踩出来的真知识，扔了等于把已修的线上 bug 重新放出来。例如：

- 「provider X 要额外剥离字段 Y」「某模型 thinking 标签格式不同要特判」「某类附件先转码」。
- chat 流式「节流 + 冻结已完成块」这类性能经验。

**做法：不抄那段 `if/else`，而是把它当一条「已知边界条件」，在新代码里干净实现 + 写成回归测试。**

### ③ 纯技术债 / 真 bug —— 修
迁移正好是还债窗口。重写时顺手修掉，并补测试。

---

## 3. 不丢「②类修复」的纪律（对拍 + 测试清单）

风险是**双向**的：

- 全抄 → 把①框架垃圾和③ bug 一起搬进来。
- 全不抄 → 漏掉②救命修复，把已修 bug 又放出来（更隐蔽）。

落地手段：

1. **把每个补丁/特判当成「已知边界条件清单」**——它们是最宝贵的回归测试用例来源。
2. 重写新层时，对照清单**逐条编码成 Dart 单测**（given provider X → 输出应剥离 Y）。
3. 关键路径做**对拍（golden / 行为比对）**：同一输入喂老 React 逻辑与新 Dart 逻辑，比对输出，揪出「干净重写」时不小心丢掉的真修复。

> 补丁不是负担，是「这里有坑」的地图：按图用测试把坑钉死，把绕坑的脏代码扔掉。

---

## 4. 迁移顺序：自底向上，UI 最后

与直觉相反，但更稳——每层都能独立验证，不会「全写完才发现跑不起来」。

```
M0  领域模型      TS types → freezed model（契约先定）
M1  数据层        Drift schema + DAO + repository 实现（可单测）
M2  网络/LLM 层    dio + SSE + 各 provider client（可单测，headless）
M3  平台抽象层     UnifiedPlatformApi + 各平台实现
M4  移动端 UI      逐页复刻（已验证可 1:1，打法见 UI_PARITY_PLAYBOOK.md）
M5  桌面端 UI      复用下层，只做 shell/导航
        ┊
   老数据迁移      IndexedDB → SQLite 一次性导入（见 §5）
```

详见 `ROADMAP.md`。

---

## 5. 老用户数据迁移（IndexedDB → SQLite）

原数据库：Dexie `aetherlink-db-new` v9（stores: topics / assistants / settings / messages / message_blocks / memories / knowledge …）。

- 新装用户：无需迁移。
- 老用户：需**一次性导入**，否则历史会话丢失。
- 方案候选（M1 阶段定稿）：
  1. 老 Web 版导出 JSON → 新 App 首启导入；
  2. 若新旧短期共存于同壳，写一段读取 IndexedDB → 写 Drift 的迁移器。
- 迁移器要覆盖所有 store，并对每张表做计数 + 抽样比对验证。

---

## 6. 硬骨头清单（提前标注，别被「都能搬」忽悠）

| 项 | 原方案 | Flutter 对策 | 难度 |
| --- | --- | --- | --- |
| 富文本编辑器 | tiptap | `super_editor` / `appflowy_editor` 重做 | 最高 |
| Mermaid 图 | mermaid | Dart 生态弱：嵌 webview 渲染 或 降级/砍 | 高 |
| MCP 客户端 | `@modelcontextprotocol/sdk` | 自写 Dart JSON-RPC | 中 |
| 代码高亮 | shiki / codemirror | `flutter_highlight` / re_highlight | 低 |
| Markdown | react-markdown | `flutter_markdown`（或 gpt_markdown） | 低 |
| LaTeX | katex | `flutter_math_fork` / `flutter_tex` | 低 |
| 图表块 | chart.js | `fl_chart` | 低 |
| 体量 | 20+ service 域 / 14 slice | 无捷径，按 feature 逐块迁 | —— |

---

## 7. 每迁一个模块的标准动作

1. 读原 React 模块，**列出它的行为契约**（输入/输出/副作用/边界条件）。
2. 把所有补丁/特判过一遍**三分类**（§2），标注扔/留/修。
3. 在对应 feature 的 `domain` 写接口 + use case；`data` 写实现；`application` 写状态。
4. 把②类边界条件写成单测；关键路径做对拍。
5. `flutter analyze` + `custom_lint` + 测试全绿，再开 PR。
6. PR 描述里写清：本次扔了哪些①、保留了哪些②、修了哪些③。
