# AetherLink「PPT Studio」总体设计 —— 覆盖并超越 Anthropic pptx + Akxan ppt-agent-skill

日期：2026-07-26　作者：Devin

> **维护约定**：本文档是 PPT 功能的单一路线图。任何会话实现/调整某个里程碑后，
> **必须同步更新下方进度表**（状态 + PR 链接），保持新会话可直接接手。

## 进度总览

| 里程碑 | 内容 | 状态 | PR |
|---|---|---|---|
| M1 | 纯 Dart PPTX 内核（deck.json → 原生 pptx + HTML 预览 + 布局 QA） | ✅ 已合并 | [#806](https://github.com/1600822305/Aetherlink-flutter/pull/806) |
| M2 | @aether/pptx 工具（pptx_check/pptx_render）+ 内置技能 | ✅ 已合并 | [#806](https://github.com/1600822305/Aetherlink-flutter/pull/806) |
| M3 | 工作区 *.deck.json 原生预览 | ✅ 已合并 | [#807](https://github.com/1600822305/Aetherlink-flutter/pull/807) |
| M4 | 原生 OOXML 图表（bar/line/pie） | ✅ 已合并 | [#808](https://github.com/1600822305/Aetherlink-flutter/pull/808) |
| — | 技能 1.3.0 专业设计规范（配色/版式/禁止清单） | ✅ 已合并 | [#809](https://github.com/1600822305/Aetherlink-flutter/pull/809) |
| M5 | 读取已有 pptx + 演讲者备注 + 结构校验 | ⬜ 未开始 | — |
| M7 | 设计引擎：风格库 JSON + Bento 布局引擎 + 图表扩到 15 种 | ⬜ 未开始 | — |
| M8 | 工作流 2.0：9 步 pipeline + 失败模式 QA + AI 配图 | ⬜ 未开始 | — |
| M6 | 模板导入 + 编辑已有 pptx | ⬜ 未开始 | — |

实施顺序：M5 → M7 → M8 → M6（先解决「好看」，最难的模板编辑放最后）。

关键代码位置：内核 `packages/aetherlink_pptx/`；工具
`lib/shared/mcp_tools/pptx/`；技能 `lib/shared/config/builtin_skills/ppt_skill.dart`
（改正文必须升 version）；预览 `lib/features/workspace/presentation/mobile/editor/deck_preview.dart`。

## 0. 目标

把两套业界最强 PPT skill 的**全部能力**移植为纯 Dart 端上实现，并利用移动端独有优势做出它们做不到的东西。一句话：

> Anthropic 的工程严谨（读/写/改/验 pptx 全链路）
> + Akxan 的设计系统（风格库/布局引擎/图表库/叙事节奏/失败模式）
> + 移动端独有（离线、真机原生预览、指尖编辑、演示模式）
> = PPT Studio

## 1. 逐项能力对照（目标 = 全覆盖）

| 能力 | Anthropic | Akxan | 我们现状 | PPT Studio 目标 |
|---|---|---|---|---|
| 从零生成可编辑 pptx | ✅ pptxgenjs(Node) | ✅ svg2pptx(Python) | ✅ 纯 Dart | ✅ 已有 |
| 原生图表 | ✅ bar/line/pie/scatter/doughnut… | ✅ 18 种(HTML/SVG) | ✅ bar/line/pie | ✅ 扩到 15+ 种（见 §4） |
| 读取/提取已有 pptx | ✅ markitdown | ❌ | ❌ | ✅ pptx_read（M5） |
| 编辑已有 pptx / 模板 | ✅ python-pptx + 原始 XML | ❌ | ❌ | ✅ pptx_edit（M6） |
| 加/删/复制/重排页 | ✅ add_slide.py/clean.py | ❌ | ❌ | ✅ M6 |
| 演讲者备注 | ✅ | ❌ | ❌ | ✅ M5 |
| 结构校验（schema/关系/图表） | ✅ validate.py + XSD | ✅ smoke_test | 部分（布局 QA） | ✅ deck_validate（M5） |
| 渲染视觉 QA | ✅ LibreOffice→图 | ✅ Playwright 截图 | ❌（无渲染器可用） | ✅ 端上截图 QA（M7，独家优势） |
| 缩略图 | ✅ thumbnail.py | — | Flutter 预览 | ✅ 预览即缩略图 + 导出 PNG |
| 风格库 | 10 色板 + 设计规范 | **26 风格**（JSON Schema 定义） | 8 色板（1.3.0） | ✅ 12-16 风格 JSON（M7），可扩展 |
| 布局引擎 | 版式建议（文字） | **Bento Grid 7 布局 + 决策矩阵** | 5 版式（文字） | ✅ layout 引擎进 deck.json（M7） |
| 卡片系统 | ❌ | 6 种卡片类型 + 内容合同 | roundRect 手拼 | ✅ card 元素（M7） |
| 工作流（调研→大纲→策划→风格→设计→QA） | 简化 | **9 步完整 pipeline** | 5 步简化 | ✅ 分阶段工作流 + 中间产物落盘（M8） |
| 失败模式目录 | NEVER 清单 | 8 种 runtime failure modes + 修复顺序 | 禁止清单（1.3.0） | ✅ 全部并入 QA 规则 + 技能 |
| 叙事节奏（密度交替/章节色/首尾呼应） | 部分 | ✅ | ❌ | ✅ M8 技能 |
| AI 配图 | ❌ | ✅（图像生成 prompt 体系） | ❌ | ✅ 接我们已有图像生成能力（M8） |
| 排版铁律（字距/tabular-nums/衬线混排） | 部分 | ✅ typography.md | 部分 | ✅ 风格 JSON 内建字距/字号分级 |
| 离线/移动端运行 | ❌ 需 Node+Python+LibreOffice | ❌ 需 Python+Playwright | ✅ | ✅ 独家 |

结论：需要补的是 6 大块 —— **读（M5）、改（M6）、风格+布局+图表引擎（M7）、工作流+配图+叙事（M8）**，其余已有或只差扩展。

## 2. 超越点（他们做不到、我们能做）

1. **端上真渲染 QA**：他们靠 LibreOffice/无头浏览器截图，渲染结果和 PowerPoint 并不一致；我们的 Flutter 预览与导出共享同一几何模型，QA 是**确定性**的，且可在手机上跑。再加"预览截图→喂回视觉模型自检"闭环（M7），QA 精度超过两者。
2. **风格即数据**：Akxan 的 26 风格写死在 markdown 里，只有 agent 能读；我们把风格做成 JSON（内置资产 + 用户可增），deck.json 只声明 `"style": "dark_tech"`，渲染器负责落地——**风格换肤一键切换**，用户不重新生成就能换风格，这是所有 skill 都做不到的。
3. **布局即引擎**：Akxan 的 Bento Grid 靠 agent 手写 CSS；我们把 7 种布局做成 deck.json 的 `layout` 声明（卡片自动定位、间距/圆角/边界由引擎保证），agent 只填内容——彻底消灭 out_of_bounds/间距不一致这类错误，而不是靠 QA 事后抓。
4. **迭代编辑**：deck 源永远在工作区，用户说"第 3 页换成对比布局"，agent 改一个字段即可；Anthropic 改已有 pptx 要解 XML，Akxan 根本改不了。
5. **离线 + 隐私**：全流程端上完成，敏感商业内容不出设备。

## 3. 架构

```text
用户一句话
  ↓ 技能「PPT 设计师 2.0」（M8 工作流）
  ├─ ① 需求对齐（场景/受众/页数/风格倾向）
  ├─ ② 资料（用户材料 + 可选搜索）
  ├─ ③ outline.json（大纲，落盘可预览）
  ├─ ④ style 选择（styles/*.json 决策矩阵）
  ├─ ⑤ deck.json（布局引擎 layout + 卡片 + 图表 + 配图）
  ├─ ⑥ pptx_check（结构 QA + 失败模式 QA）
  ├─ ⑦ 预览截图 → 视觉自检（可选）
  └─ ⑧ pptx_render 导出 + deck 源存工作区
工具层（@aether/pptx）
  pptx_check / pptx_render（已有）
  pptx_read（M5）· pptx_edit（M6）
内核（packages/aetherlink_pptx，纯 Dart）
  deck_document + style_registry + layout_engine（M7）
  pptx_writer / pptx_reader（M5）/ pptx_editor（M6）
  deck_qa（+失败模式规则）· html/flutter 渲染器
```

## 4. 分里程碑详设

### M5 读取 + 备注 + 结构校验（≈3 天工作量）
- `pptx_reader.dart`：解压 zip → 解析 slide/notes/table/chart XML → 输出 markdown 或 deck.json 骨架。工具 `pptx_read(path)`（只读免审批）。用途：总结别人的 PPT、把已有 PPT 转成 deck 源迭代。
- 演讲者备注：deck.json 每页加 `"notes": "..."`，写入 `notesSlide` part；预览页可显示。
- `deck_validate`：内容类型/关系完整性/图表引用自检（对齐 validate.py 的检查面），并入 pptx_check。

### M6 编辑已有 pptx + 模板（≈1 周，最难）
- `pptx_editor.dart`：解压 → 定位 shape/文本 → 替换/增删 → 维护 [Content_Types].xml 与 .rels → 重打包。
- 能力：改文本、换图、加/删/复制/重排幻灯片（对齐 add_slide.py/clean.py）、基于用户上传的 .pptx/.potx 模板填内容（保留母版样式）。
- 工具 `pptx_edit(path, operations[])`，写文件需确认。
- 风险：任意第三方 pptx 的 XML 变体多，先支持"我们生成的 + 常见 Office 模板"，逐步放宽。

### M7 设计引擎：风格库 + 布局引擎 + 图表扩展（≈1 周）
- **风格库**：`assets/deck_styles/*.json`，字段对齐 Akxan schema（bg/card/text/accent/字号字距分级/装饰开关/forbidden 清单）。首批 12 个覆盖 5 大板块（dark_tech、xiaomi_orange、luxury_purple、blue_white、minimal_gray、medical_pulse、fresh_green、champagne_gold、vibrant_rainbow、bauhaus_block、royal_red、ink_jade），决策矩阵进技能。deck.json：`"style": "dark_tech"`，元素颜色可全部省略由风格推导；用户可放自定义风格 JSON 到工作区。
- **布局引擎**：页级 `"layout": {"type": "hero_top", "cards": [...]}`，内置 7 种 Bento 布局（单焦点/50-50/2:1 非对称/三栏/主次/英雄式/混合网格）+ 封面/目录/章节/结束 4 种页型；卡片 6 类型（text/data/list/tags/process/big_number）自动排版。仍兼容现有绝对坐标元素（混用）。
- **图表扩展**：原生 OOXML 新增 doughnut、area、scatter、stackedBar、horizontalBar、radar（共 9 种原生）；纯形状合成图表：progress、kpi 卡、waffle、timeline、funnel、gauge（导出后仍是可编辑形状组）。合计 15 种，附数据特征→图表决策矩阵。
- **视觉自检**：预览页支持"整 deck 截图导出 PNG"，agent 生成后可读图自查（利用多模态）。

### M8 工作流 2.0：技能重写 + 配图 + 叙事（≈3 天）
- 技能升 2.0：9 步 pipeline、中间产物落盘（outline.json/style 选择）、密度交替节奏、章节强调色递进、封面-结尾呼应、8 失败模式 + 修复顺序铁律（先内容→再支撑→再锚点→最后装饰）。
- QA 增加失败模式规则：underfill 升级（字数阈值）、support_collapse（内容页卡片<3 或类型<2）、anchor_overexpansion（单卡>65% 面积）、deck_rhythm_clone（连续 3 页同布局）。
- 配图：接入 App 已有图像生成（生成→base64 进 image 元素），风格 JSON 附配图 prompt 模板；无图像模型时降级为色块/形状装饰。

## 5. 排期与顺序

M5(读+备注+校验) → M7(设计引擎，对"好看"影响最大) → M8(工作流) → M6(模板编辑，最难放最后)。总计约 3-4 周，每个里程碑独立 PR、独立可用。

## 6. 风险

- M6 第三方 pptx 兼容性 → 分层支持，先自家格式。
- 风格字体依赖（Inter/衬线）→ 移动端只能声明字体名降级到系统字体，视觉与 Akxan 的 Google Fonts 版有差距；可选打包 1-2 个开源中文字体。
- 形状合成图表（radar/gauge 等非 OOXML 原生）在 PowerPoint 里是形状组而非"图表对象"——可编辑但不能改数据重算，需在技能里说明。
- deck.json 复杂度上升 → 布局引擎把复杂度移进内核，agent 面对的 schema 反而更简单。
