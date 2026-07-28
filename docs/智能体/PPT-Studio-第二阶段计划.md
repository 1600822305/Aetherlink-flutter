# PPT Studio 第二阶段计划 —— 开放性、质量与效率

日期：2026-07-28　作者：Devin

> **维护约定**：与 `PPT-Studio-路线图.md` 同款——任何会话实现/调整某个里程碑后，
> **必须同步更新下方进度表**（状态 + PR 链接），保持新会话可直接接手。
> 第一阶段（M1-M8，从零生成 + 编辑已有 pptx + 设计引擎 + 工作流 2.0）已全部完成，
> 见 `PPT-Studio-路线图.md`。

## 进度总览

| 里程碑 | 内容 | 优先级 | 状态 | PR |
|---|---|---|---|---|
| P1 | 工作区自定义风格 JSON（约定目录 + pptx_styles 集成） | 高 | ✅ 已完成 | [#825](https://github.com/1600822305/Aetherlink-flutter/pull/825) |
| P2 | 效率：大纲 → 引擎自动展开初稿（模型只做增量修改） | 高 | ✅ 已完成 | [#826](https://github.com/1600822305/Aetherlink-flutter/pull/826) |
| P3 | 视觉自检闭环（整 deck 截图 → 多模态自查） | 高 | ✅ 已完成 | [#827](https://github.com/1600822305/Aetherlink-flutter/pull/827) |
| P4 | 外部 Agent Skills 通路（skill 包 + 内置终端执行） | 中 | ✅ 已完成 | [#828](https://github.com/1600822305/Aetherlink-flutter/pull/828) |
| P5 | PPT 风格库设置页（全局设置入口，可选） | 低 | ⬜ 未开始 | — |
| P6 | 多页并行生成（subagent 分页写） | 低 | ✅ 已完成 | [#829](https://github.com/1600822305/Aetherlink-flutter/pull/829) |

## 0. 背景与定位

第一阶段把 Anthropic pptx + Akxan ppt-agent-skill 的能力移植为纯 Dart 端上实现。
两个新问题：

1. **封闭性**：PPT 能力全部硬编码——技能是 360 行 Dart 常量
   （`lib/shared/config/builtin_skills/ppt_skill.dart`），deck.json 是私有格式，
   只有内置 9 个 `pptx_*` 工具认识它。外部任何 PPT skill（如 anthropic/skills
   的 pptx）都插不进这条流水线；项目技能加载
   （`lib/app/di/agent_project_skills_access.dart`）只读 SKILL.md 正文，
   skill 包的 `scripts/`、`references/`、`assets/` 被完全忽略。
2. **与专业工具的差距**：手动编辑能力和生成效率都不如专业 PPT 工具。

**定位铁律：不做编辑器。** WPS/PowerPoint 移动端已是免费的专业编辑器，
导出的 .pptx 原生可编辑；合理分工是「AI 生成 + 自然语言迭代」在我们这，
「精修」交给 WPS。差异化只有一个：*用户一句话就能改，而不是自己动手*。

内置纯 Dart 内核是刻意取舍（离线、确定性 QA、原生预览、一键换风格），
**不推翻**；问题是内核是唯一路径、技能层封闭。第二阶段的主题：
保留内置路线为默认最优路径，同时打开外部通路、补齐质量闭环、降本提效。

## 1. P1 工作区自定义风格 JSON（高，≈1 天）

现状：自定义风格只能在 deck.json 里内联 JSON 对象
（`deck_style.dart` 的 `DeckStyle.resolve` 只认内置 12 个 id 或内联对象）；
路线图 M7 写的「用户可放自定义风格 JSON 到工作区」未实现。

- 约定目录：工作区 `.aetherlink/deck_styles/*.json`，文件名即风格 id
  （如 `my_brand.json` → `"style": "my_brand"`）。字段对齐
  `DeckStyle.fromJson` 现有 schema（background/cardFill/textPrimary/
  textSecondary/accents 必填）。
- `pptx_styles` 列表合并工作区风格（标注来源 workspace）；
  `pptx_check` / `pptx_render` / `pptx_edit` 解析 style id 时
  先查工作区再查内置，同名工作区优先（允许覆盖内置）。
- 解析失败（缺字段/坏 hex）报清晰错误，不静默回退。
- 技能正文补一段「自定义风格」用法，**升 version**。
- agent-first 玩法（文档/技能里写明）：用户可以让智能体
  「照我们公司 VI 生成一个风格文件」，全程不碰设置页。

## 2. P2 效率：引擎自动展开初稿（高，≈2-3 天）

现状最大的效率洞：LLM 逐字写整份 deck.json（几十 KB JSON），
慢、贵、易错。9 步 pipeline 里第 6 步「展开 deck 源」占了大部分 token。

- 大纲格式升级：`*.outline.json` 结构化（每页：页型/layout 类型/
  标题/要点/数据），schema 进 `pptx_schema`。
- 新工具 `pptx_draft(outline, style)`：布局引擎按大纲**确定性展开**
  完整 deck.json 初稿落盘（页型映射、卡片分配、叙事节奏规则
  ——密度交替、章节色递进——全部引擎内置）。
- 模型职责收缩为：写大纲 → `pptx_draft` → 按 QA/用户反馈用
  `pptx_edit` 增量改。token 预期降一个量级。
- 技能工作流从「逐页手写 deck」改为「draft + 增量修改」，升 version。

## 3. P3 视觉自检闭环（高，≈1 周）

「好看」差距最大的一块：现有 QA 只有几何规则（out_of_bounds/
text_overflow/…），看不到「丑」。路线图 M7/M8 两次遗留。

- 离屏 widget 渲染管线：复用 deck 预览渲染器，整 deck 逐页
  截图导出 PNG 到工作区（新工具 `pptx_snapshot(deck, pages?)`，
  或并入 `pptx_render(snapshot: true)`）。
- 技能加一步：导出前把截图喂回多模态模型自检
  （对比度、拥挤、对齐、风格一致性），按反馈 `pptx_edit` 修正。
- 无多模态模型时跳过，不算失败（对齐 pptx_illustrate 的降级约定）。
- 优势：预览与导出共享同一几何模型，截图即真实产物，
  QA 是确定性的（Anthropic 靠 LibreOffice、Akxan 靠 Playwright，
  渲染都和 PowerPoint 不一致）。

## 4. P4 外部 Agent Skills 通路（中，≈1-2 周）

把技能系统从「SKILL.md 纯文本」升级到完整 Agent Skills 规范，
让内置终端（Termux/proot/SSH，本来就是真 Linux 环境）能直接跑
anthropic/skills 这类带脚本的 skill 包。

- 项目技能识别整个 skill 包：`SKILL.md` + `scripts/` + `references/`
  + `assets/`；`read_skill` 返回正文后，agent 用文件读取 + 终端
  逐层加载执行（渐进披露，文件路径相对 skill 根目录解析）。
- skill 可在 frontmatter 声明依赖（如 `requires: [python3, python-pptx]`）；
  终端后端可用时技能可用，不可用时在技能清单里标注降级原因。
- 优先级：同名外部技能 > 内置技能（允许用户用外部 skill
  覆盖内置 PPT 设计师，含那份设计规范）。
- 脚本执行走现有终端 HITL 审批，不新开安全口子。
- 全局技能库（`Skill` 模型只有 `content` 字符串）暂不动，
  先做工作区项目技能这条路——skill 包本来就该住在工作区里。
- 内置 `pptx_*` 保留为默认路径（离线 / 无终端 / iOS 场景）。

## 5. P5 PPT 风格库设置页（低，可选，≈2-3 天）

P1 落地后如需 UI 再做。**放全局设置，不放智能体设置**：
风格库是全局资源（与技能库同级），不是某个智能体的运行时配置。

- 入口与 `skills_settings_page` 平级；页面：12 内置风格色板预览
  + 导入 JSON 文件 + 启/停用 + 删除自定义。
- 不做大而全的「PPT 专业设置页」——目前除风格库没有别的可设置项，
  页面会很空；等有默认风格/默认画布比例等选项再升级不迟。
- 导航遵守项目约定：零时长路由（参考 `mcp_server_edit_page.dart`）。

## 6. P6 多页并行生成（低，≈3 天）

- P2 落地后，剩余的模型改写工作（逐页精修）可用现有 subagent
  机制分页并行：每页一个 subagent 拿到大纲 + 风格 + 本页上下文，
  产出该页的 `pptx_edit` ops。
- 注意叙事节奏是跨页约束（密度交替/章节色），并行时由
  引擎（P2 的 draft）保证，subagent 只在页内改。
- 依赖 P2，收益递减，最后做。

## 7. 实施顺序与理由

P1（便宜、立即可用）→ P2（效率大头）→ P3（质量大头）→
P4（开放性，工程量大）→ P5/P6（可选）。

P1+P2 一周内可完成，用户可感知的提升最快；P3 决定「好看」上限；
P4 决定生态上限。

## 8. 风险

- P2：引擎展开的初稿设计质量不如模型手写 → 叙事节奏规则内置到
  draft 引擎，且模型仍可 `pptx_edit` 全量覆盖，最坏退回现状。
- P3：离屏渲染在低端机上的内存/耗时 → 逐页渲染即释放，允许指定页码子集。
- P4：任意脚本执行的安全面 → 全部走终端 HITL 审批；skill 包只从
  工作区加载，不做远程安装。
- P4：iOS 无终端 → 技能清单明确标注「需要终端」，降级到内置路线。
