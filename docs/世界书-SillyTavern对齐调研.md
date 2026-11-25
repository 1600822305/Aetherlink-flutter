# 世界书 · 与 SillyTavern 对齐调研

> 状态：调研稿 + 已拍板的方向；**P0 数据模型已完成（2026-11-26）**，见下方进度。
> 目的：在改数据模型之前，把 SillyTavern（下称 ST）世界书的真实字段与执行语义、本项目的现状、两者差距、需要拍板的问题一次讲清楚。
> 日期：2026-11-26

---

## ★ 进度

| 阶段 | 状态 | 说明 |
|---|---|---|
| P0 数据模型 | ✅ 完成 | 条目改为 ST 原生结构（全部字段 + `extra`）；书的 JSON 就是 ST 文件；新增 `WorldBookSettings`（ST 默认值，尚未持久化）；导入不再禁用条目，改为统计 `pendingEntryCount`；导出即 ST 格式；删除 `world_book_selection.dart`、`world_book_st_export.dart` |
| P1 匹配层 | ✅ 完成 | 逐关键词 `/正则/flags`、区分大小写 / 全词匹配跟随全局、扫描深度跟随全局、次级关键词四种逻辑、按 `order` 排序；扫描文本同 ST（最近的在前、`\x01` 分隔、`名字: ` 前缀）；宏替换（`world_book_macros.dart`：名字、时间、random / pick / roll、newline / trim / 注释、reverse，关键词匹配前与内容注入前各替换一次）。**未覆盖的宏**：`{{lastMessage}}` 等依赖聊天上下文的、`{{datetimeformat}}`、`{{idle_duration}}`、变量类 `{{getvar}}` / `{{setvar}}`、嵌套宏 |
| P2 激活控制 | ✅ 完成 | `selectTimedWorldBookEntries` 改为 ST `checkWorldInfo` 的多轮扫描循环：概率（持续中的不重判，失败的本次不再参与）、包含组（持续中胜出 / 评分 / 已激活的组移除 / 组内优先 / 权重随机，支持多组）、预算（百分比 + 上限、不计入预算、`budgetOverflowed`）、递归（阻止 / 不可被递归激活 / 延迟到递归层级 / 最大扫描次数）、最少激活数（全局深度逐次 +1，受深度上限与聊天长度约束）。递归、最少激活数、预算上限在「全局设置」里打开。**限制**：① 上下文长度拿不到（模型上没有这个字段），预算只受上限约束；② token 用 `estimateTokens` 估算；③ 「延迟到递归层级」的层级推进按 ST 逻辑只在开启递归时进行；④ 预算溢出后「不计入预算」条目的处理按源码推断，需对照测试确认 |
| P3 语义对齐 | ✅ 完成 | ① **计时器按消息条数**（ST `chat.length`）：时钟 `resolveWorldBookClock` 数路径上的用户 + 助手消息（摘要不计）；持续 `turn < C + sticky`；冷却无持续时从激活起算、有持续时从持续到期那条起算（`WorldBookEffect.cooldownFrom`）；延迟 `turn < delay`，且最先判断；状态版本升到 3。② **深度按消息计**：深度 n 插在最后 n 条消息之前。③ **同一深度 assistant → user → system 各一条**，不同深度深的在前（按 ST chat completion `populationInjectionPrompts` 推断）。④ **user 角色原样插入**（不再包 `<system>`）；**system 角色**在 OpenAI 兼容协议下原样发 system 消息，Anthropic / Gemini 降级为 user + `<system>` 包裹；深度 0 的 assistant 按 system 处理，避免末尾助手预填。⑤ **装饰器** `@@activate` / `@@dont_activate`（含 `@@@` 后备写法），注入与递归都用去掉装饰器行的内容。**已知差异**：「继续生成」沿用该用户消息的序号（ST 会多算一条正在续写的助手消息）；多模型组合（思考 + 生成）路径按降级方式发 system |
| P4 外部概念 | ✅ 完成（除作者注释 / 示例消息） | ① **生成类型**：发送 / 重新发送 / 多模型 = `normal`，重新生成 = `regenerate`，继续 = `continue`；本应用不会产生 `impersonate` / `quiet` / `swipe`。② **角色筛选**：角色 = 当前助手，名字筛选匹配助手名或 id（不区分大小写），标签筛选匹配助手标签（助手没有标签时跳过，同 ST），支持排除模式；编辑页新增「角色筛选」。③ **额外匹配源**：角色描述 = 助手系统提示词，角色性格 = 助手简介，场景 = 话题提示词；人设 / 角色备注 / 作者备注本应用没有对应内容，为空。④ **Outlet**：系统提示词里的 `{{outlet::名字}}` 替换成同名 Outlet 条目内容（名字不区分大小写，没有对应条目替换为空）。⑤ **作者注释、示例消息**：本应用没有这两个概念，仍只保存不注入。新增 `world_book_scan_context.dart`。**仍「暂不生效」的**：作者注释 / 示例消息位置、向量匹配、自动化 ID、人设 / 角色备注 / 作者备注匹配源、只限定代写 / 后台生成的条目 |
| 设置持久化与界面 | ✅ 完成 | `WorldBookSettingsController`（KV 键 `worldBookSettings`，JSON 键名沿用 ST `world_info_*`）；发送时 `readWorldBookSettings` 直接读存储；世界书页右上角「全局设置」入口（`world_book_settings_page.dart`）：扫描深度、包含名字、区分大小写、全词匹配、递归与最大扫描次数、最少激活数与深度上限（两者互斥）、预算上限与上下文百分比、组评分、超出预算提示（暂不生效）；条目编辑页的「跟随全局」提示读真实设置 |

「暂未生效」的判定集中在 `worldBookPendingFeatures`（world_book_import.dart），每完成一项就从里面删掉对应规则。

---

## ★ 已定方向（2026-11-26，优先于下文的草案）

**前提：** 世界书功能还没上线，**不考虑迁移和旧数据兼容**，一切以和 ST 原生世界书行为一致为目标。

由此带来的设计变化：

1. **内部模型直接采用 ST 的条目结构。** 字段名、默认值、`null` 表示跟随全局等语义都和 ST 一样，不再单独维护一套本项目的字段再做换算。
   - 去掉 `priority`，直接用 `order`（越大越靠近末尾）；
   - 去掉条目级 `useRegex`，改成和 ST 一样每个关键词单独写 `/p/flags`；
   - `position` / `role` / `selectiveLogic` 直接用 ST 的取值。
2. **本应用自己的导出格式就是 ST 格式**，只多出书级字段（`enabled`、`description`、分组）放在扩展字段里，ST 会忽略。这样导入导出天然无损，§5 的换算方案和 `world_book_st_export.dart` 里的大部分降级逻辑都不需要了。
3. **「聊天顶部 / 聊天底部」去掉。** ST 里没有这两个位置，「聊天底部」等价于 @深度 0，「聊天顶部」没有对应。
4. **计时器、深度注入按消息条数计算**，和 ST 一样；不做旧数据迁移。
5. **@深度支持 system 角色**，是否发成 system 消息、深度 0 的助手消息要不要处理，交给请求层按供应商能力决定（见下文第 6 条），引擎本身和 ST 一致。
6. **供应商兼容放在最后一层。** 引擎产出和 ST 一样的注入结果；遇到不支持聊天中间 system 消息、或不接受末尾助手消息的供应商，只在发请求前做降级，不影响激活逻辑。
7. **未知字段原样保留**（`extra`），保证 ST 以后新增字段也能往返。

§6 剩下的问题，按「尽量原生」先这样定，做到对应阶段时再细化：

| # | 问题 | 定为 |
|---|---|---|
| 1 | 计时器单位 | 消息条数，同 ST |
| 2 | 深度注入计数 | 消息条数，同 ST |
| 3 | system 角色 | 支持；供应商不支持时在请求层降级 |
| 4 | 角色筛选 | 「角色」= 助手（名字 = 助手名，标签 = 助手标签）|
| 4 | 额外匹配源 | 角色描述 / 性格 / 场景等 = 助手的提示词字段；人设 = 用户资料；本项目没有的来源为空串 |
| 4 | 作者注释、示例消息 | 先只保存不生效；本项目以后有这两个概念再接 |
| 4 | Outlet | 实现：内容按名字收集，提示词里用 `{{outlet::名字}}` 取出 |
| 4 | 生成类型 | 正常发送 = normal，继续 = continue，重新生成 = regenerate，多版本 = swipe |
| 4 | 自动化 ID、向量匹配 | 只保存；向量匹配以后单独评估 |
| 5 | 全局设置 | 先做一套全局设置，同 ST |
| 6 | 预算 token | 先用现有估算器，接口留好以后换真实 tokenizer |
| 7 | 宏 | 实现 ST 的 `{{char}}` `{{user}}` 等常用宏 |
| 8 | 包含名字 | 用户名 = 用户资料里的名字（没有就是 User），助手名 = 助手名 |

---

## 0. 资料来源与可信度

| 来源 | 用途 | 说明 |
|---|---|---|
| ST `public/scripts/world-info.js`（release 分支，经 jsDelivr 获取的压缩版） | 字段定义、默认值、激活主循环、包含组、计时器、注入拼装、角色卡世界书转换 | **以此为准**。压缩版里少数函数体被截断：装饰器解析 `parseDecorators` 的内部、预算初值的计算开头、`delay` 判断的那一行。这几处用官方文档和未压缩版前半部分补足 |
| ST 官方文档 *World Info*（docs.sillytavern.app） | 各功能的用户语义 | 与源码有一处冲突：文档说「全词匹配默认开启」，源码里 `world_info_match_whole_words` 默认是 `false`。**以源码为准** |
| 本项目代码 | 现状 | `world_book_entry.dart`、`world_book_import.dart`、`world_book_timed_selection.dart`、`world_book_turn_state.dart`、`world_book_injector.dart`、`world_book_request_builder.dart`、`world_book_tables.dart` |

ST 一直在迭代，下面的结论对应获取当天的 release 分支。真动手实现某一项时，应再对照一次那一段源码。

---

## 1. ST 的数据模型

### 1.1 文件结构

- 独立世界书文件：`{ "entries": { "<uid>": <entry>, ... } }`，书名就是文件名，没有书级开关。
- 内嵌在角色卡里的世界书（Character Card V2 `character_book`）字段名不同，ST 用一张映射表转换，见 §1.5。
- 编辑器会给缺字段的条目补齐默认值（`addMissingWorldInfoFields`），所以**实际文件里字段可能不全**，导入时必须按默认值兜底。

### 1.2 条目字段全表（`newWorldInfoEntryDefinition`）

带 `?` 的类型可以为 `null`，`null` 表示**继承全局设置**。

| 字段 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `uid` | int | — | 书内唯一编号，也是 `entries` 的键 |
| `key` | string[] | `[]` | 主关键词，可混写 `/正则/flags` |
| `keysecondary` | string[] | `[]` | 次级关键词（可选过滤器） |
| `selective` | bool | `true` | 是否启用次级关键词 |
| `selectiveLogic` | enum | `0` | 次级逻辑：0 与任一，1 非全部，2 非任一，3 与全部 |
| `comment` | string | `""` | 标题 / 备注，不参与匹配 |
| `content` | string | `""` | 注入内容 |
| `constant` | bool | `false` | 常驻（蓝灯） |
| `vectorized` | bool | `false` | 允许按向量相似度激活（链接图标） |
| `disable` | bool | `false` | 条目关闭 |
| `addMemo` | bool | `false` | 显示备注（纯 UI） |
| `order` | number | `100` | 插入顺序，越大越靠近提示词末尾 |
| `position` | number | `0` | 注入位置，见 §1.3 |
| `depth` | number | `4` | 仅 `position = 4` 时有效 |
| `role` | enum | `0` | 仅 `position = 4` 时有效：0 system、1 user、2 assistant |
| `outletName` | string | `""` | 仅 `position = 7` 时有效 |
| `probability` | number | `100` | 触发概率（0–100） |
| `useProbability` | bool | `true` | 是否启用概率 |
| `group` | string | `""` | 包含组，逗号分隔可属于多个组 |
| `groupOverride` | bool | `false` | 组内优先：同组按 `order` 最大者胜出，不随机 |
| `groupWeight` | number | `100` | 组内随机权重（1–10000） |
| `useGroupScoring` | bool? | `null` | 组内按关键词命中数评分 |
| `scanDepth` | number? | `null` | 扫描深度（条消息），0–1000 |
| `caseSensitive` | bool? | `null` | 区分大小写 |
| `matchWholeWords` | bool? | `null` | 全词匹配 |
| `excludeRecursion` | bool | `false` | 不可被递归激活 |
| `preventRecursion` | bool | `false` | 激活后不再触发递归 |
| `delayUntilRecursion` | number \| bool | `0` | 只在递归阶段激活；数字表示递归层级 |
| `matchPersonaDescription` | bool | `false` | 额外匹配源：用户人设描述 |
| `matchCharacterDescription` | bool | `false` | 额外匹配源：角色描述 |
| `matchCharacterPersonality` | bool | `false` | 额外匹配源：角色性格 |
| `matchCharacterDepthPrompt` | bool | `false` | 额外匹配源：角色备注（depth prompt） |
| `matchScenario` | bool | `false` | 额外匹配源：场景 |
| `matchCreatorNotes` | bool | `false` | 额外匹配源：作者备注 |
| `sticky` | number? | `null` | 持续 N 条消息 |
| `cooldown` | number? | `null` | 冷却 N 条消息 |
| `delay` | number? | `null` | 聊天至少有 N 条消息才可激活 |
| `ignoreBudget` | bool | `false` | 不计入 token 预算 |
| `automationId` | string | `""` | 激活时联动快速回复脚本 |
| `triggers` | string[] | `[]` | 限定生成类型：normal / continue / impersonate / swipe / regenerate / quiet |
| `characterFilter` | `{isExclude, names[], tags[]}` | 无 | 角色筛选，按角色文件名或标签包含 / 排除 |
| `displayIndex` | number | 同 `uid` | 编辑器里的显示顺序，不影响注入 |

### 1.3 枚举

| 枚举 | 取值 |
|---|---|
| `position` | 0 角色定义之前、1 角色定义之后、2 作者注释顶部、3 作者注释底部、4 @深度、5 示例消息之前、6 示例消息之后、7 Outlet |
| `selectiveLogic` | 0 AND_ANY、1 NOT_ALL、2 NOT_ANY、3 AND_ALL |
| `role`（@深度） | 0 system、1 user、2 assistant |
| 合并策略 | 0 均匀排序、1 角色书优先（默认）、2 全局书优先 |

### 1.4 全局设置（`world_info_*`）

| 设置 | 默认 | 说明 |
|---|---|---|
| `depth` | 2 | 全局扫描深度（条消息） |
| `min_activations` / `min_activations_depth_max` | 0 / 0 | 最少激活数：不足时继续往更早的消息扫描；与最大递归层数互斥 |
| `budget` | 25 | 预算占上下文的百分比 |
| `budget_cap` | 0 | 预算上限（token），0 不限 |
| `include_names` | true | 扫描文本里带「名字:」前缀 |
| `recursive` | false | 递归扫描 |
| `max_recursion_steps` | 0 | 0 只受预算限制 |
| `case_sensitive` | false | 条目未指定时的默认值 |
| `match_whole_words` | false | 同上（文档写的是默认开启，与源码不符） |
| `use_group_scoring` | false | 同上 |
| `overflow_alert` | false | 超出预算时弹提示 |
| `character_strategy` | 1 | 合并策略 |

### 1.5 角色卡 V2 字段映射（`originalWIDataKeyMap` / `convertCharacterBook`）

角色卡里的字段改名后放在 `extensions` 下，例如 `order ↔ insertion_order`、`key ↔ keys`、`keysecondary ↔ secondary_keys`、`disable ↔ !enabled`、`position ↔ extensions.position`（顶层 `position` 只有 `before_char` / `after_char` 两个值）、`depth ↔ extensions.depth`、`group ↔ extensions.group`、`sticky ↔ extensions.sticky` 等。导入角色卡内嵌世界书时要按这张表转换。

ST 还能导入 Agnai、RisuAI、NovelAI 的世界书，各有一个转换函数，字段都映射到上面这一套。

---

## 2. ST 的执行语义

### 2.1 条目来源与排序

1. 按顺序合并：聊天世界书 → 人设世界书 → 角色书和全局书（按合并策略）。每一组内按 `order` 从大到小排。
2. 解析每条内容开头的装饰器（`@@activate` / `@@dont_activate`），从内容里去掉。
3. 对每条的 JSON 算哈希。计时器靠这个哈希认条目：**改了条目的任何字段，正在进行的计时都会失效**。

### 2.2 扫描文本

- 最近的消息排在前面；深度 N 就是最近 N 条消息，用户和助手的都算。条目没设深度时用全局深度，默认 2。
- 每条消息前面加 `\x01` 分隔符；打开「包含名字」时还会带上「名字:」前缀。
- 条目打开了额外匹配源的，会把角色描述、人设等文本追加进来。
- 递归阶段会再追加已激活条目的内容（最少激活数的补扫不追加）。

### 2.3 关键词匹配（`matchKeys`）

- 匹配前先做宏替换（`substituteParams`）。
- 写成 `/pattern/flags` 的关键词按正则处理：**直接匹配原文**，大小写由正则的 flags 决定，不受条目「区分大小写」影响。写法不合法时当作普通文本。
- 普通关键词：先按「区分大小写」决定要不要转小写。
  - 「全词匹配」开启、关键词是单个词：用 `(?:^|\W)关键词(?:$|\W)` 匹配。
  - 关键词含空格：仍是子串匹配。
  - 「全词匹配」关闭：子串匹配。
  - 中文没有空格分词，打开全词匹配基本匹配不到，官方文档也建议中文关闭。

### 2.4 每个条目的判定顺序

对每个条目依次判断，命中前面的规则就不再往下：

1. 本轮已激活或已判定失败 → 跳过
2. `disable` → 跳过
3. `triggers` 不包含本次生成类型 → 跳过
4. 角色筛选（名字 / 标签，包含 / 排除）不通过 → 跳过
5. 处于 `delay` → 跳过
6. 处于冷却，且没有持续 → 跳过
7. `delayUntilRecursion`：非递归阶段跳过；递归阶段层级未到也跳过
8. 递归阶段，且 `excludeRecursion` → 跳过
9. 装饰器 `@@activate` → 激活；`@@dont_activate` → 跳过
10. 被外部强制激活 → 激活
11. `constant` → 激活
12. 处于持续 → 激活
13. 没有主关键词 → 跳过
14. 任一主关键词命中 → 有次级关键词时按 `selectiveLogic` 判定，没有就直接激活

### 2.5 候选处理

1. **排序：** 处于持续的条目排在最前，其余保持 §2.1 的顺序。
2. **包含组：**
   - 一个条目可以属于多个组，用逗号分隔；
   - 组里有处于持续的条目时它直接胜出；处于冷却或延迟的条目被移出；
   - 开启评分时，只保留关键词命中数最高的那些；
   - 这个组在之前的递归轮已经激活过，本轮整组移除；
   - 有 `groupOverride` 的取 `order` 最大的；否则按 `groupWeight` 加权随机选一个。
3. **概率：** 开启概率且不是 100 时随机判定；处于持续的不重新判定；判定失败的条目本次扫描内不再参与。
4. **内容宏替换。**
5. **预算：**
   - 按「上下文 × 百分比」算出预算，再受上限约束；
   - 按顺序累加 token，超出就停止激活后续条目，可选弹提示；
   - `ignoreBudget` 的条目不受预算限制。

### 2.6 递归与最少激活数

- **递归：** 开启后，本轮新激活、且没设 `preventRecursion` 的条目，内容会加进扫描文本，再扫一轮；`max_recursion_steps` 限制总轮数。
- **延迟递归层级：** 按数字从小到大逐层放开。
- **最少激活数：** 激活数不够时，扫描深度每轮加 1，直到够数、碰到深度上限或聊天开头为止。

### 2.7 注入拼装

- 激活的条目按 `order` 排序，**`order` 小的先拼，大的更靠近末尾**。同一 `order` 的条目在拼装时会被倒过来（本项目导入时倒序读回键，就是为了抵消这一点）。
- **注入前处理：** 内容会先过 ST 的正则脚本扩展（作用位置为 World Info）。
- **各位置的去向：**
  - 位置 0 / 1：拼成「角色定义前 / 后」两段文本；
  - 位置 2 / 3：包在作者注释前后，作者注释关闭时直接丢弃；
  - 位置 5 / 6：作为示例对话块；
  - 位置 4：按「深度 + 角色」分组，变成插在倒数第 N 条消息处的扩展提示，**N 按消息条数算**，没设角色时默认 system；
  - 位置 7：按 outlet 名存起来，提示词里用 `{{outlet::名字}}` 取出。

### 2.8 计时器

- 状态存在聊天元数据里，以 `书名.uid` 为键，记录 `{hash, start, end, protected}`。**单位是消息条数**（`chat.length`），不是轮次。
- **持续：** 激活时记 `start = 当前消息数`、`end = start + sticky`，消息数小于 `end` 时一直生效，期间不重新判定概率。
- **冷却：** 激活时同时记一份冷却；持续结束时再从那一刻重新开始计冷却，所以效果上是「持续结束后才开始冷却」。
- **延迟：** 当前消息数小于 `delay` 时不能激活。`delay = 1` 只排除空聊天。
- **回退处理：** 聊天没有前进（最后一条被重新生成或删除）时，非保护状态的计时会被清掉。

---

## 3. 本项目现状

### 3.1 数据与存储

- 条目字段：`id`、`name`、`enabled`、`priority`、`position`（5 种）、`content`、`injectDepth`、`role`（只有用户 / 助手）、`keywords`、`useRegex`、`caseSensitive`、`scanDepth`（默认 4）、`constantActive`、`sticky`、`cooldown`、`delay`。
- 书：`id`、`name`、`description`、`enabled`、`entries`、`groupName`。
- **存储：** 一本书一行，条目整体存成 JSON（`WorldBookRows.data`）。**加字段不需要改数据库结构**，只要改 `fromJson` / `toJson` 和默认值。
- **代码生成：** `WorldBook` / `WorldBookEntry` 是 freezed 类，加字段后要重新生成 `.freezed.dart`。
- **未知字段会丢：** `fromJson` 只读认识的字段，不认识的直接丢掉。所以现在从 ST 导入，再导出成本应用格式，ST 的字段就没了。

### 3.2 激活

- **触发条件：** 条目开启、内容不为空，并且是常驻，或者任一关键词命中。没有次级关键词、概率、组、递归、预算。
- **扫描文本：** 最近 N 条用户 / 助手消息的请求文本。N 取条目自己的 `scanDepth`，没有全局默认；不带名字前缀，也没有分隔符。
- **正则：** 条目级开关 `useRegex`，打开后**所有关键词**都当裸 pattern，大小写跟随条目设置。
- **计时器：**
  - **单位是用户轮次**；
  - 持续：`经过的轮数 ≤ sticky` 都算生效（含边界）；
  - 冷却：紧接在持续之后；
  - 延迟：`轮次 ≤ delay` 时不能激活；
  - 计时状态存在用户消息的元数据上。
- **排序：** `priority` 大的在前，同值时按书序、条目序。导入时 `priority = -order`，所以和 ST 的先后方向一致。

### 3.3 注入

- 系统提示词之前 / 之后：拼进 system 文本。
- 聊天顶部 / 底部 / 指定深度：作为整条消息插在**消息段之间**，不会拆开工具调用和工具结果。
- 指定深度的 N 按**用户消息段**数，不是按消息条数。
- 角色只有用户 / 助手。用户角色的内容外面包一层 `<system>…</system>`；深度 0 的助手角色强制改成用户，避免末尾出现助手预填。
- 生产环境默认会把注入的用户消息合并进相邻的用户消息（`kWorldBookMergeAdjacentUser`）。

---

## 4. 差距矩阵

类型说明：**缺失** = 本项目没有；**语义不同** = 都有，但算法或单位不一样，导入后行为会变；**有意差异** = 本项目为了兼容各家供应商主动做的取舍。

| # | 功能 | ST | 本项目 | 类型 | 影响 |
|---|---|---|---|---|---|
| 1 | 计时器单位 | 消息条数 | 用户轮次 | 语义不同 | 一来一回 2 条消息算 1 轮，导入后持续 / 冷却时长大约变成两倍 |
| 2 | 持续边界 | 消息数 < end，不含边界 | 经过轮数 ≤ sticky，含边界 | 语义不同 | 同上，再差一格 |
| 3 | 延迟 | 消息数 < delay 时不能激活 | 轮次 ≤ delay 时不能激活 | 语义不同 | delay=1 在 ST 里几乎不起作用，在本项目里会挡掉第 1 轮 |
| 4 | 扫描深度默认 | `null` 继承全局 2 | 条目自己存，默认 4 | 语义不同 | 导入时已把 `null` 换成 2；新建条目默认值和 ST 不一样 |
| 5 | 区分大小写 / 全词默认 | `null` 继承全局 | 只有条目级布尔，没有全词匹配 | 语义不同 + 缺失 | 没法表达「跟随全局」 |
| 6 | 正则写法 | 每个关键词可以单独写成 `/p/flags` | 条目级开关，裸 pattern | 语义不同 | 正则和普通词混写的条目没法表达 |
| 7 | 扫描文本格式 | 名字前缀 + `\x01` 分隔 | 纯文本用换行拼接 | 语义不同 | 依赖 `\x01` 或名字的正则匹配不上 |
| 8 | 深度注入计数 | 按消息条数 | 按用户消息段 | 语义不同 | 深度相同时插入位置不同 |
| 9 | @深度 system 角色 | 支持，而且是默认值 | 不支持 | 有意差异 | 部分供应商会丢掉聊天中间的 system 消息 |
| 10 | 深度 0 助手角色 | 支持 | 强制改成用户 | 有意差异 | 避免末尾助手预填 |
| 11 | 同深度多角色顺序 | 按 (深度, 角色) 分组 | 按角色首次出现顺序 | 语义不同 | 混用角色时顺序不同 |
| 12 | 次级关键词 + 四种逻辑 | 有 | 无 | 缺失 | 很常用 |
| 13 | 全词匹配 | 有 | 无 | 缺失 | 主要影响英文世界书 |
| 14 | 宏替换（关键词 + 内容） | `{{char}}` `{{user}}` 等 | 无 | 缺失 | 角色卡世界书大量使用；项目里已有 `system_prompt_variables.dart`，可以复用 |
| 15 | 概率 | 有 | 无 | 缺失 | |
| 16 | 包含组（权重 / 优先 / 评分） | 有 | 无 | 缺失 | |
| 17 | 递归（含 3 个开关、最大层数、延迟层级） | 有 | 无 | 缺失 | |
| 18 | 最少激活数 | 有 | 无 | 缺失 | |
| 19 | Token 预算 / 上限 / 溢出提示 / 不计预算 | 有 | 无 | 缺失 | 大世界书会把上下文撑爆 |
| 20 | 装饰器 `@@activate` / `@@dont_activate` | 有 | 导入时标为不支持 | 缺失 | |
| 21 | 生成类型触发 | 有 | 无 | 缺失 | 需要先把本项目的生成类型对应过来 |
| 22 | 角色筛选 | 有 | 无 | 缺失 | 需要先确定「角色」对应什么（助手？） |
| 23 | 额外匹配源 | 6 种 | 无 | 缺失 | 需要确定对应来源（助手提示词？用户资料？） |
| 24 | 作者注释顶部 / 底部 | 有 | 无 | 缺失 | 本项目没有作者注释的概念 |
| 25 | 示例消息前 / 后 | 有 | 无 | 缺失 | 本项目没有示例对话的概念 |
| 26 | Outlet | 有 | 无 | 缺失 | 需要提示词里支持 `{{outlet::名字}}` 宏 |
| 27 | 聊天顶部 / 聊天底部 | 无 | 有 | 本项目独有 | 导出到 ST 要降级（已实现） |
| 28 | 正则脚本作用于世界书内容 | 有 | 未确认 | 待查 | 本项目有 `AssistantRegex`，需要确认是否对世界书内容生效 |
| 29 | 多书合并策略 | 3 种 | 助手绑定 / 话题覆盖 / 全局默认，书序即注入序 | 设计不同 | 不需要照搬 |
| 30 | 向量匹配 | 有 | 无 | 缺失 | 依赖嵌入模型 |
| 31 | 自动化 ID | 有 | 无 | 缺失 | 依赖 ST 的快速回复脚本，基本不适用 |
| 32 | 未知字段保留 | ST 编辑器会补默认值，不会主动丢字段 | 读入即丢 | 缺失 | **这是第一步要解决的** |

---

## 5. 数据模型方案（草案，等你拍板 §6 后再定）

### 5.1 原则

1. **字段取 ST 的超集。** ST 有的字段全部能存下来；「继承全局」的字段用可空类型表示。
2. **原样保留未知字段。** 条目和书各加一个 `extra` 字段，存所有不认识的键。导出 ST 格式时原样写回，保证往返无损，也能兼容 ST 以后新增的字段。
3. **旧文件不受影响。** 本应用 JSON 只在新字段不等于默认值时才写入。没用到新功能的书导出后和现在完全一样，RikkaHub 兼容性不变。
4. **只存不用要明确提示。** 引擎还没实现的字段先只保存，编辑页标「暂不生效」，导入提示也要写清楚，不让用户误以为已经生效。
5. **不改数据库结构。** 条目本来就是 JSON 存储，只需要改模型和编解码。

### 5.2 条目建议新增的字段

| 字段（本项目） | 对应 ST | 类型 | 默认 | 备注 |
|---|---|---|---|---|
| `secondaryKeywords` | `keysecondary` | `List<String>` | `[]` | |
| `secondaryLogic` | `selectiveLogic` | enum 4 值 | `andAny` | 再加一个 `selective`（默认 true） |
| `matchWholeWords` | `matchWholeWords` | `bool?` | `null` | |
| `caseSensitive` | 同名 | **改成 `bool?`** | 迁移时旧值原样保留 | `null` = 跟随全局 |
| `scanDepth` | 同名 | **改成 `int?`** | 旧值原样保留 | `null` = 跟随全局 |
| `probability` / `useProbability` | 同名 | `int` / `bool` | 100 / true | |
| `groups` | `group` | `List<String>` | `[]` | ST 是逗号分隔的字符串，导入导出时转换 |
| `groupOverride` / `groupWeight` / `useGroupScoring` | 同名 | bool / int / `bool?` | false / 100 / null | |
| `excludeRecursion` / `preventRecursion` | 同名 | bool | false | |
| `delayUntilRecursion` | 同名 | `int` | 0 | ST 的 `true` 存成 1 |
| `ignoreBudget` | 同名 | bool | false | |
| `triggers` | 同名 | `Set<enum>` | 空 = 全部 | |
| `characterFilter` | 同名 | 对象 | 无 | 先只保存 |
| `matchSources` | 6 个 `match*` | `Set<enum>` | 空 | 先只保存 |
| `outletName` | 同名 | String | `""` | |
| `automationId` / `vectorized` | 同名 | String / bool | "" / false | 只保存，供往返 |
| `extra` | 未知键 | `Map<String, dynamic>` | `{}` | |

**枚举扩展：**
- `position` 新增 `beforeExamples`、`afterExamples`、`authorNoteTop`、`authorNoteBottom`、`outlet`；
- `role` 新增 `system`。

加枚举值会让现有的穷举 `switch` 编译报错，需要一起改的地方：
- `world_book_entry_row.dart` 的位置标签；
- `world_book_entry_form_sections.dart` 的位置说明和选择器；
- `world_book_injector.dart` 的 `_isChatPosition` 和合并逻辑；
- `world_book_import.dart` 和 `world_book_st_export.dart` 的映射。

**保持不变：**
- `priority`：继续用「越大越靠前」，导入导出用 `±order` 换算，现有逻辑已经验证过；
- `useRegex`：保留，兼容旧条目。同时支持在关键词里写 `/p/flags`，和 ST 一样逐个关键词判断。

### 5.3 新增全局设置（单独一个模型，存应用设置）

字段对应 §1.4：扫描深度、区分大小写、全词匹配、包含名字、递归、最大递归层数、最少激活数和它的深度上限、预算百分比、预算上限、溢出提示、组评分。

另外需要决定，是否允许每个助手单独覆盖这些设置（见 §6 第 5 条）。

### 5.4 书

书级字段保持现状：`enabled`、`description`、`groupName` 都是本项目自己的。只增加 `extra`，用来保留 ST 文件顶层不认识的键。

---

## 6. 需要你拍板的问题

1. **计时器单位：** 改成和 ST 一样按**消息条数**，还是保留按用户轮次、只在导入导出时换算（不能精确换算）？
   - 想要完全对齐，就得改成按消息条数。
   - 改了之后，已经设置过计时器的旧条目，时长会变成原来的一半左右，可以考虑做一次迁移（数值乘 2）。
2. **深度注入计数：** 同样，改成按消息条数，还是保留按用户消息段？
3. **@深度 system 角色：** 要不要支持？之前不支持，是因为部分供应商会丢掉聊天中间的 system 消息。
   - 可选做法：存下来并支持；遇到不支持中间 system 消息的供应商，自动降级成「用户角色 + `<system>` 包裹」。
4. **本项目没有的概念，每一项怎么处理**（对应 / 只保存不生效 / 不做）：
   - 角色筛选：「角色」对应助手吗？
   - 额外匹配源：角色描述对应助手提示词？人设对应用户资料？
   - 作者注释、示例消息：本项目没有；
   - Outlet：要不要在提示词里支持 `{{outlet::名字}}`；
   - 生成类型：正常 / 继续 / 重新生成 / 多版本，各对应 ST 的哪一种；
   - 自动化 ID、向量匹配。
5. **全局设置的作用范围：** 只有一套全局设置，还是每个助手可以覆盖？
6. **预算用什么算 token：** 用现有的估算器 `estimateTokens`，还是接真实的 tokenizer？两者结果会有偏差。
7. **宏：** 现有的 `system_prompt_variables.dart` 用的是 `{xxx}` 写法，ST 用 `{{char}}` `{{user}}`。要不要把 ST 的宏当别名支持？`char` / `user` 分别对应什么？
8. **「包含名字」** 需要知道每条消息的发言者名字。本项目里用户和助手的名字分别取什么？

---

## 7. 建议的实施顺序

每个阶段做完，都从导入的「不支持」清单（`_hasUnsupportedRules` 等）里删掉对应规则，并补上对照测试。

| 阶段 | 内容 | 完成标准 |
|---|---|---|
| **P0 数据模型** | 按 §5 扩展字段和 `extra`；新增全局设置模型；导入导出改成用全部字段；编辑页把暂未生效的字段放进「高级 · 暂不生效」 | ST 文件导入后再导出 ST 格式，除了已知的降级项，内容一致；本应用旧文件读写结果不变 |
| **P1 匹配层** | 次级关键词和四种逻辑、全词匹配、逐个关键词的 `/正则/`、大小写和扫描深度跟随全局、关键词和内容的宏替换、包含名字和 `\x01` 分隔 | 对照测试：同一本书、同一段对话，激活集合和 ST 一致 |
| **P2 激活控制** | 概率、包含组（加权 / 优先 / 评分）、预算（含不计预算和溢出提示）、递归（3 个开关、最大层数、延迟层级）、最少激活数 | 同上，加上随机部分用固定种子测试 |
| **P3 语义对齐** | 计时器单位和边界、深度计数、system 角色、同深度多角色顺序、装饰器 | 同上，按 ST 文档里的计时示例逐条消息验证 |
| **P4 依赖外部概念的功能** | 按 §6 第 4 条的结论实现角色筛选、生成类型、额外匹配源、Outlet 等 | 看决定的范围 |

**对照测试的做法：** 在本地跑一个 ST，用同一本世界书和同一段聊天，从 ST 控制台的 `[WI]` 日志里拿到激活条目清单，存成测试样例，本项目的引擎逐条对比。没有这一步，很难说结果和酒馆一样。

---

## 8. 附：两边字段对照速查

| ST | 本项目现有 | 导入时的现有处理 |
|---|---|---|
| `uid` | `id` | 转字符串 |
| `comment` | `name` | 为空时用第一个关键词 |
| `content` | `content` | 原样；以 `@@` 开头或含宏 → 标为不支持 |
| `key` | `keywords` | 原样；含 `/正则/` → 标为不支持 |
| `keysecondary` | — | 非空 → 标为不支持 |
| `constant` | `constantActive` | 原样 |
| `disable` | `!enabled` | 不支持的条目会被强制关闭 |
| `order` | `priority = -order` | 缺省 100 |
| `position` | 0 / 1 / 4 → 之前 / 之后 / 指定深度 | 其他值 → 标为不支持 |
| `depth` | `injectDepth` | 限制在 0–200 |
| `role` | 2 → 助手，其余 → 用户 | system 角色 → 标为不支持 |
| `scanDepth` | `scanDepth` | `null` → 2 |
| `caseSensitive` | `caseSensitive` | `null` → false |
| `sticky` / `cooldown` / `delay` | 同名 | 持续 / 冷却不为 0 → 标为不支持 |
| 其他字段 | — | 读入即丢；有非默认值的部分字段会被标为不支持 |
