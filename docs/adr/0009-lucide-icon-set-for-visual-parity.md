# ADR-0009：图标集采用 lucide（视觉 1:1 保真），引入首个第三方 UI 依赖

- **状态**：Accepted（**新决策**，不推翻任何既有 ADR；与 **ADR-0008**「可主题化系统」互补——0008 钉的是配色/形状/装饰层等 token 化的「主题」，本 ADR 钉的是「图标集」这一块视觉资产怎么选。**修订**此前只存在于历次 M4 交接提示词里的非正式护栏「UI chrome 零新依赖、图标用 Flutter 内置 `Icons.*` 近似」——该护栏从未写进任何 ADR，故无需 `Supersedes`，本 ADR 即为这条口子的正式定调。）
- **日期**：2026-06-15
- **决策者**：Kenneth + 架构师会话

## 背景（Context）

逐页复刻进行到 ChatPage（M4.2）与设置页时，Kenneth 反复指出新版「根本就不一样」「不是像、我要一模一样」。复盘根因有二：① 拿空壳跟满屏对话比（阶段性，非缺陷）；② **已经画出来的 chrome 是「通用 Flutter 味」而非 Aetherlink**——其中很大一块是**图标**。

- 原项目 `1600822305/Aetherlink` 全程用 **lucide-react**（仓库内 246 处引用），图标是产品视觉识别的一部分。
- 此前 M4.0 / M4.2.0b 交接提示词为压依赖、保持「零新依赖」，要求实现方用 Flutter 内置 `Icons.*` **近似** lucide（如 联网≈`Icons.public`、语音≈`Icons.mic`）。结果：图标只是「形似」，**逐个看都不对**，叠加 Material 默认观感，整体「不像 Aetherlink」。
- Flutter 生态有 lucide 的原生端口包（与 lucide 同一套 SVG path），用它能做到**图标逐个一模一样**，而不是另找一套风格相近的图标。

约束与前情：

- **视觉保真已被 Kenneth 列为硬指标**（ROADMAP M4 验收：核心页面与原版视觉对比 ≥ 95%）。图标对不上，95% 无从谈起。
- 既有非正式护栏「零新依赖」在**平台层**早已被 ADR-0007 打破（买 19 个插件那条路），说明本项目的依赖政策本就是「该买就买、按判据筛」，而非教条零依赖。图标集是同一类「买现成、别自己造」的判断。
- 死规矩不变：分层 `presentation → application → domain ← data`；`domain` 纯 Dart 零 Flutter import（图标是 Flutter `IconData`，**只能待在 presentation**，不许泄进 domain/application）。

核心张力：「零新依赖」的纯粹 vs「视觉 1:1」的产品要求。在图标这一项上，二者冲突，必须选一边。

## 选项（Options）

1. **继续用 Flutter 内置 `Icons.*` 近似**：零依赖，但图标只能「形似」，与「一模一样」的硬指标直接冲突；且 Material 图标集与 lucide 风格语言不同（线宽/圆角/隐喻），越铺越不像。
2. **采纳 lucide 的 Flutter 端口包**（如 `lucide_icons_flutter`）：和 lucide-react 同一套图标，**逐个一模一样**；代价是引入一个第三方 UI 依赖 + 一份维护面。
3. **把原版用到的 lucide SVG 自己搬进项目当 asset**（`flutter_svg` 或预栅格化）：也能 1:1，但要么仍引 `flutter_svg` 依赖 + 手动搬几十上百个 SVG（维护面更大、易漏），要么栅格化丢失矢量/换色灵活性；等于自己维护半套图标库。
4. **自画图标字体**：重造轮子，成本最高，无收益。

## 决策（Decision）

选 **2**：**采纳 lucide 的 Flutter 端口包（首选 `lucide_icons_flutter`——覆盖全、活跃维护、用法 `LucideIcons.xxx`）作为全 app 的图标集**，逐页复刻一律用 lucide 同名图标，**不再用 `Icons.*` 近似**。这是本迁移**第一个第三方 UI（presentation）依赖**——明确「视觉 1:1 保真」在图标这一项上**优先于**「零新依赖」的纯粹性。

### 划线规则一：图标只认 lucide 同款，不许近似
- 复刻任何页面，图标 = 原版 lucide 对应的同名 `LucideIcons.*`；**禁止**再用 Flutter 内置 `Icons.*` 充数（除非原版该处本就不是 lucide，需在 PR 里点明）。
- 选包标准：覆盖原版用到的全部 lucide 图标、活跃维护、版本可 pin。先用 `lucide_icons_flutter`；若发现更全/更稳的 lucide 端口可换，但**必须是 lucide 原生同款 path**，不接受「风格相近」的第三方图标集。

### 划线规则二：依赖政策——UI 资产「买现成」需过判据，且单独记录
- 引入第三方 UI 依赖照 ADR-0007 同款判据筛：成熟度、维护活跃度、覆盖度、可替换性。图标包满足。
- 本 ADR 把口子限定在**图标集**这一项。**不等于**此后 UI 层可随意加依赖——markdown 渲染、代码高亮等仍是各自独立的取舍，**要加先单独评估/记 ADR**，别拿本 ADR 当「UI 随便加包」的通行证。

### 划线规则三：图标是 presentation 资产，不许下沉
- `IconData`/`LucideIcons.*` 是 Flutter 类型，**只能出现在 presentation**。导航 catalog、widget 里用图标 OK；**domain 仍纯 Dart 零图标**（过 `import_boundaries_test`）；application 层若需表达「某条目用哪个图标」，用纯 Dart 的语义标识（enum/key），由 presentation 映射成 `LucideIcons.*`，不让 `IconData` 泄进 application/domain。

### 划线规则四：与主题 token（ADR-0008）的关系
- 图标**形状**来自 lucide（本 ADR）；图标**颜色/尺寸**仍走主题 token（ADR-0008 的配色角色 / `AppThemeExtension`），**零硬编码色**不变。两者正交：lucide 给「画什么」，主题给「什么颜色多大」。

## 理由（Rationale）

- **「一模一样」的硬指标只有选项 2/3 能满足，2 的维护面最小**：端口包随上游 lucide 同步，不用自己搬几十个 SVG、不用自己管栅格化；用法 `LucideIcons.xxx` 与 `Icons.xxx` 同构，迁移成本近乎零。
- **「零新依赖」本就不是本项目的教条**：ADR-0007 已确立「平台层该买就买」。图标集是同一类判断——自己造/近似的成本与风险（不像、维护面）高于「用成熟现成包」。在图标这一项上为视觉保真放开一个受控依赖，是一致的判据、不是破例。
- **把口子限定在图标、并要求后续 UI 依赖单独评估**，避免「开了图标的口子 → UI 层依赖泛滥」的滑坡，保留对依赖面的控制。
- **图标锁在 presentation**，维持分层纯净：domain 不因视觉资产而被污染，边界测试照旧卡得住。

## 后果（Consequences）

- **正面**：图标与原版逐个一致，视觉保真度的最大短板之一被补上；`LucideIcons.*` 用法直观、可换色（走主题 token）、矢量清晰；后续每页复刻都能直接对上原版图标。
- **负面 / 代价**：
  - 引入首个第三方 UI 依赖（一份维护面 + 跟随上游版本）——用「pin 版本 + 选活跃维护的包」对冲。
  - 端口包的图标可能与最新 lucide 有版本差；若原版用到的某图标包里没有，需在 PR 点明并找等价 lucide 名或临时降级。
  - 打破了历次交接里「零新依赖」的口径，需在 SSOT（本 ADR + 后续交接）统一口径，避免实现方/复审拿旧规矩卡。
- **护栏（加新东西时照这个走，别破）：**
  1. **图标只认 lucide 同款**，不许 `Icons.*` 近似；颜色/尺寸仍走主题 token（零硬编码色）。
  2. **依赖口子仅限图标集**；其它 UI 依赖（markdown/代码高亮/图表…）各自单独评估，必要时记 ADR，别援引本 ADR 放行。
  3. **图标锁 presentation**；`IconData` 不下沉 application/domain，domain 保持纯 Dart 过边界测试。
  4. 图标包**pin 明确版本**，升级当独立改动评估。
- **未来若要推翻的触发条件**：所选 lucide 端口包长期失修 / 覆盖度跟不上上游 lucide（则换包或转「搬 SVG asset」方案，单独评估）；或产品决定整体换用非 lucide 的图标语言（则新开 ADR 标 `Supersedes: ADR-0009`）。
