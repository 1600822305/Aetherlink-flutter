import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// 内置 skill：PPT 设计师——deck.json 源格式、设计规范与
/// pptx_check / pptx_render 工作流（渐进披露，对齐 read_skill 模式）。
const Skill kPptSkill = Skill(
  id: 'builtin-ppt-designer',
  name: 'PPT 设计师',
  description:
      '用 @aether/pptx 生成专业演示文稿的完整流程：deck.json 源格式、'
      '排版设计规范、QA 自检循环与导出',
  emoji: '📊',
  tags: ['PPT', '幻灯片', '演示文稿', '设计'],
  source: SkillSource.builtin,
  version: '2.4.0',
  author: 'AetherLink',
  enabled: true,
  content: '''
## 能力概览

`@aether/pptx` 有**两条互不替代**的路线，先选对路线再动手：

- **A. 从零生成**（默认）：写 deck.json 源 → `pptx_render` 出片。用我们自己的
  母版和 12 套风格库，设计质量最高，可增量迭代。适合「帮我做一份 PPT」。
- **B. 改已有文件**：`pptx_outline` 看结构 → `pptx_modify` 在 OOXML 层原地改。
  **母版/主题/版式/字体全部保留**。适合「按公司模板填内容」「改这份 PPT 的
  某几句话」「把这份 PPT 的第 3 页删了」。

选错路线的典型后果：拿到用户的公司模板却走 A，母版和 VI 全丢；
只想改一个错别字却走 A，整份 PPT 被重做一遍。

十一个工具：

- `pptx_schema`：返回 deck.json 的 JSON Schema（只读，免审批）——格式的
  单一权威来源，含别名容错说明；字段/结构不确定或 check 报错时先调它自查。
- `pptx_styles`：列出视觉风格库（只读，免审批）：内置 12 套 + 工作区自定义。
- `pptx_read`：读取工作区里已有的 .pptx/.potx（只读，免审批），逐页提取
  文本/表格/图表数据/演讲者备注；`format: "markdown"`（默认，适合总结
  和问答）或 `format: "deck"`（输出 deck.json 骨架，适合把已有 PPT 转成源
  继续迭代；骨架里图片不内嵌、布局是估算值，要按设计规范重排）。
- `pptx_draft`：把结构化大纲确定性展开为完整 deck.json 初稿并落盘
  （.deck.json），布局/坐标/卡片分配/叙事节奏全部引擎内置；
  大纲格式调 `pptx_schema` 看 outlineSchema。
- `pptx_check`：校验 deck 源 + 布局 QA + 包结构自检（不写文件，免审批）。
- `pptx_snapshot`：视觉自检——把某一页离屏渲染成 PNG 截图随结果注入
  上下文，直接看图检查美丑（不写工作区，免审批）。
- `pptx_render`：QA 通过后导出 .pptx 到工作区；
  可传 `preview: true` 同时导出 .preview.html 预览。
- `pptx_edit`：增量编辑——以工作区的 .deck.json 为源应用 ops（只改一页/
  一个元素），写回源文件；传 `export` 同时重导出 .pptx（可覆盖旧导出）。
- `pptx_illustrate`：AI 配图——用已配置的图像生成模型把 prompt 生成为
  图片存进工作区，image 元素用 `"src": "<路径>"` 引用；没有图像模型时
  返回错误（此时降级为色块/形状装饰，不要反复重试）。
- `pptx_outline`：列出已有 pptx 每页的 shape 清单（只读，免审批）——
  走路线 B 的第一步，`pptx_modify` 的下标全部来自它。
- `pptx_modify`：直接编辑已有 .pptx/.potx（路线 B）。原地覆盖用户文件时
  需要确认；传 `output` 另存则免确认。

## 标准工作流（9 步 pipeline，中间产物全部落盘）

1. **需求对齐**：主题、场景、受众、页数、风格倾向（深色/浅色、正式/活泼）、
   语言。信息不全先问，不要凭空猜。
2. **收集资料**：用户给的材料优先；数据/案例不足时可用网络搜索补充
   （有该工具时），标注来源。
3. **写结构化大纲并落盘**：按 outlineSchema 写 `主题.outline.json`
   （每页：kind + 标题 + 1-6 条要点），用 file-editor 的 `write` 落盘，
   发给用户过目再继续——大纲返工比整 deck 返工便宜一个量级。
4. **选风格**：`pptx_styles` 看目录，按主题/受众选 `style` 并说明理由
   （科技发布→dark_tech，医疗→medical_pulse，年报→champagne_gold …）。
5. **配图（可选）**：需要照片/插画的页先 `pptx_illustrate` 生成进工作区
   （prompt 贴合风格：写清主体、构图、配色关键词，不要要求文字入图）；
   没有图像模型时用色块/形状/infographic 装饰代替，不算失败。
6. **引擎展开初稿**：`pptx_draft(outline, path: "主题.deck.json")` ——
   布局、坐标、卡片分配、叙事节奏（密度交替/章节序号/目录自动生成）
   全部引擎确定性完成，**不要逐字手写整份 deck**；需要手写坐标的
   特殊页（全幅图/图表页）再用 `pptx_edit` 对单页精修。
7. **QA 循环**：初稿自带 QA 报告；按 errors/warnings 用 `pptx_edit`
   逐条改 → `pptx_check` 重查，直到 errors 为空（修复顺序见「失败模式」）。
   几何 QA 通过后做**视觉自检**：逐页 `pptx_snapshot(source, page)`
   看截图，检查文字溢出/遮挡、对比度不足、留白失衡、对齐问题，
   发现问题用 `pptx_edit` 改完再截图复查；看不到图（非多模态模型）
   则跳过此步，不算失败。
8. **导出**：`pptx_render` 导出（路径如 `演示文稿/主题.pptx`），deck 源
   已由 draft 落盘为 `主题.deck.json`：用户点开可直接预览；
   要人工视觉复核时可传 `preview: true` 同时导出 .preview.html。
9. **增量迭代**：后续修改一律 `pptx_edit`，不要重发完整 deck：
   `pptx_edit(source: "主题.deck.json", ops: [...], export: "主题.pptx")`。
   ops 支持 set_meta(title/style/layout) / set_slide / insert_slide /
   remove_slide / move_slide / set_element / append_element /
   remove_element（索引从 0 起，按顺序应用）。例：只改第 3 页标题 →
   `{"op":"set_element","slide":2,"index":0,"element":{…新文本元素…}}`。

## deck.json 源格式

坐标单位**英寸**，16x9 画布为 13.33 × 7.5（4x3 为 10 × 7.5）。

```json
{
  "layout": "16x9",
  "style": "dark_tech",
  "title": "文件标题",
  "slides": [
    {
      "background": "0F1115",
      "notes": "演讲者备注（可选）：写入 PPT 备注页，预览也会显示",
      "elements": [
        { "type": "text", "x": 1, "y": 2.5, "w": 11.3, "h": 1.5,
          "valign": "middle", "lineSpacing": 1.2,
          "paragraphs": [
            { "runs": [ { "text": "标题", "bold": true, "size": 40,
                "color": "FFFFFF", "font": "微软雅黑" } ],
              "align": "center" },
            { "runs": [ { "text": "要点", "size": 16 } ],
              "bullet": true, "indentLevel": 0 }
          ] },
        { "type": "shape", "shape": "roundRect", "x": 1, "y": 5,
          "w": 3, "h": 0.8, "fill": "1A73E8",
          "fillTransparency": 20, "radius": 0.15,
          "lineColor": "5F6368", "lineWidth": 1 },
        { "type": "image", "x": 9, "y": 3, "w": 3, "h": 2,
          "data": "<base64 PNG/JPEG>" },
        { "type": "image", "x": 5, "y": 3, "w": 3, "h": 2,
          "src": "https://…/photo.png 或 工作区相对路径/logo.jpg" },
        { "type": "table", "x": 1, "y": 3, "w": 7, "h": 2,
          "colWidths": [3, 4],
          "headerFill": "1A73E8", "headerColor": "FFFFFF",
          "borderColor": "DADCE0",
          "rows": [ ["表头1", "表头2"],
                    [ { "text": "值", "align": "center" },
                      { "runs": [ { "text": "加粗值", "bold": true } ] } ] ] },
        { "type": "chart", "chart": "bar", "x": 1, "y": 1.5,
          "w": 6, "h": 4.5, "title": "季度营收",
          "categories": ["Q1", "Q2", "Q3"],
          "series": [ { "name": "2025", "values": [12, 18, 15],
                        "color": "1A73E8" } ] }
      ]
    }
  ]
}
```

要点：

- shape 取值：`rect` / `roundRect`（radius 0-0.5，短边比例）/
  `ellipse` / `line`（h 可为 0，用 lineColor+lineWidth）/
  `pie`（扇形，需 angleStart/angleEnd，0=3 点钟方向顺时针）。
- align：left/center/right；valign：top/middle/bottom。
- chart 取值（9 种原生 OOXML 图表，可在 PowerPoint 里改样式）：
  `bar` / `line` / `pie` / `doughnut` / `area` / `scatter` /
  `stackedBar` / `horizontalBar` / `radar`；每个 series 的 values 长度
  必须等于 categories 长度；饼图/环形图只支持 1 个 series；雷达图至少
  3 个 categories；scatter 的 categories 写数字字符串作 x 值；
  color 省略时用风格 accents 或默认色板。
- infographic（形状合成信息图，展开为可编辑形状组）：
  `{ "type": "infographic", "kind": "progress|kpi|waffle|timeline|funnel|gauge",
  "x":.., "y":.., "w":.., "h":.. }`＋各自字段：
  progress/waffle/gauge 要 `value`(0-100)+可选 `label`；
  kpi 要 `value`(字符串)+`label`+可选 `trend`("+12%"/"-3%")；
  timeline 要 `steps`(字符串或 {label, desc} 数组)；
  funnel 要 `stages`([{label, value}])。

## 风格系统（style）

顶层 `"style": "<id>"` 套用内置风格（目录调 `pptx_styles`，含
 dark_tech/xiaomi_orange/luxury_purple/blue_white/minimal_gray 等 12 个）：
背景、文字色、卡片色、图表配色、字体全部自动推导，元素**不写颜色**即可；
显式写了的颜色优先。也可传内联对象自定义（background/cardFill/
textPrimary/textSecondary/accents 必填）。不传 style 则完全手动控制。

**工作区自定义风格**：把风格 JSON 存为工作区
`.aetherlink/deck_styles/<id>.json`（文件名即风格 id，字段同内联对象，
可选 name/category/cardBorder/backgroundAccent/titleSize 等），deck 直接
`"style": "<id>"` 引用；同名覆盖内置风格，`pptx_styles` 会一并列出
（source: workspace）。用户要求按公司 VI 做风格时：用 file-editor 把
风格文件写进该目录，后续所有 deck 都能复用。

## Bento 布局引擎（页级 layout，强烈推荐）

每页用 `"layout": {...}` 声明代替手写坐标，坐标/间距/边界由引擎保证，
可与 elements 混用（layout 元素在底层）：

- 页型：`{"type":"cover","title":..,"subtitle":..,"meta":..}` /
  `{"type":"toc","items":[2-6条]}` /
  `{"type":"section","title":..,"label":"PART 01","lead":..}` /
  `{"type":"end","title":..,"items":[..],"meta":..}`。
- 内容页（需 title + cards）：`focus`(1 卡) / `split`(2 卡 50/50) /
  `asymmetric`(2 卡 2:1) / `columns`(3 卡等宽) / `hierarchy`(3 卡，
  左主右两小) / `hero`(3-5 卡，顶部横幅+下排) / `grid`(4-6 卡网格)。
- 卡片 6 类：`{"type":"text","title":..,"body":[段落]}` /
  `{"type":"data","value":"87%","label":..,"desc":..}` /
  `{"type":"list","title":..,"items":[≥2条]}` /
  `{"type":"tags","title":..,"tags":[≥3个]}` /
  `{"type":"process","title":..,"steps":[≥3步]}` /
  `{"type":"big_number","value":..,"label":..}`。
- 相邻内容页换着用不同布局；卡片类型也要混搭（data+list+tags 比
  全 text 好看得多）。

## 叙事节奏（整篇结构，不只是单页好看）

- **三明治结构**：cover（深）→ toc → section/内容页交替 → end（深，
  视觉呼应封面：同一强调色、同一构图语言）。
- **密度交替**：重信息页（grid/columns 多卡）之后跟一页轻的
  （focus 大数字/金句/全幅图），密→疏→密，给观众喘息点。
- **章节强调色递进**：多章节长 deck 里，每个 section 页依次用
  accents 里的下一个强调色（accent(0)→accent(1)→…），观众能凭颜色
  感知进度。
- 连续 3 页同一布局会触发 deck_rhythm_clone 警告——写大纲时就把
  布局排开。

## 硬性规则（违反会被拒绝或产出损坏文件）

- 颜色一律 **6 位 hex**（如 `1A73E8`），不带 `#`、不带 alpha；
  透明度用独立的 `fillTransparency`（0-100）。
- 列表用 `bullet: true` + `indentLevel`（0-8），**不要**把 `•` 写进正文。
- 图片用 `data`（PNG/JPEG base64）或 `src`（http(s) URL 或工作区文件路径，
  单张 ≤10MB）；src 在 pptx_render/pptx_edit 导出时自动下载/读取并内联，
  优先用 src（省 token）；未展开前预览显示占位框。
- 表格每行列数必须一致。
- 所有元素不得超出画布（QA 会报 out_of_bounds error）。

## 演讲者备注

- 每页可选 `"notes": "..."`（纯文本，支持 \\n 分段），导出时写入原生
  notesSlide 备注页，演示者视图可见。
- 备注写给演讲人看：讲稿口弩、数据出处、过渡提示；**不要**把备注
  内容做成页面上的文本框。

## 读取已有 PPT（pptx_read）

- 总结/问答：`pptx_read(path)` 拿 markdown（含每页文本、表格、图表数据、
  备注）。
- **重做**已有 PPT（要换成我们的设计）：`pptx_read(path, format: "deck")`
  拿 deck 骨架 → 按设计规范重排版（骨架只保留内容，坐标是估算值）→
  `pptx_check` → `pptx_render` 导出新文件，不要覆盖原文件。
- **保留原样式**地改：走下面的路线 B，不要用 pptx_read 转 deck。

## 路线 B：编辑已有 pptx / 套用模板（pptx_outline + pptx_modify）

用户给了 .pptx/.potx 并且**要保留它的母版、配色、字体**时走这条。

### 固定三步

1. `pptx_outline(path)` —— 拿到每页的 shape 清单。重点看 `placeholder`：
   `title`/`ctrTitle` 是标题位，`body`/`subTitle` 是正文位，这些就是模板的
   填充点。`text` 字段是当前内容，用来确认自己找对了 shape。
2. 规划 ops。**先在脑子里过一遍下标变化**（见下）。
3. `pptx_modify(path, ops, output?)` —— 一次把所有 ops 发过去，
   工具会按顺序施加并做包结构自检，不通过就不写文件。

### 下标会变，这是最容易出错的地方

ops 依次施加，`duplicate_slide`/`delete_slide`/`move_slide` 都会改变后面
op 看到的页码。两条铁律：

- **删多页时从后往前删**：删 [1,3,5] 要写成 delete 5 → delete 3 → delete 1。
  从前往后删会连环错位。
- **先复制够页数，再逐页填内容**：复制阶段用 `at` 明确指定落点，
  填内容阶段下标就固定了。

### 套模板的标准姿势

模板通常只有 1-2 页样板页。把样板页复制 N 份，再逐页填字，最后删掉样板原页：

```
ops: [
  {op:"duplicate_slide", slide:1, at:2},
  {op:"duplicate_slide", slide:1, at:3},
  {op:"set_text", slide:2, shape:0, text:"第一章 市场分析"},
  {op:"set_text", slide:3, shape:0, text:"第二章 竞品对比"},
  {op:"delete_slide", slide:1}
]
```

.potx 模板**不能原地改**，必须传 `output` 指定要生成的 .pptx。

### 各 op 的注意事项

- `set_text` 整体替换一个 shape 的文字，`\\n` 分段，原字体/字号/颜色保留。
  这是改文字的**首选**。
- `replace_text` 只在单个文本 run 内匹配。PowerPoint 常把一句话拆进多个
  run（改过格式、拼写检查都会拆），所以「明明有这句话却替换不到」是正常的
  ——改用 `set_text` 整体重写那个 shape。批量换公司名/年份这类短词才用它。
- `set_notes` 在没有备注页时会自动新建；包里连 notesMaster 都没有时会报错，
  这时如实告诉用户，不要反复重试。
- `replace_image` 的 `src` 支持 http(s) URL 或工作区路径（PNG/JPEG ≤10MB），
  `image` 是该页第几张图（0 基）。图片是等位替换，**原图的位置和尺寸框不变**，
  所以新图长宽比差太多会被拉伸——挑比例接近的图。
- 改不动的东西：`pptx_modify` 不能新增文本框/形状/图表，也不能改位置尺寸。
  需要这些就走路线 A 从 deck 生成。

### 安全

原地覆盖用户文件要过确认；不确定就传 `output` 另存一份新文件，
把原文件留给用户。

## 设计规范（不要做无聊的幻灯片）

白底黑字加一排项目符号的页面毫无记忆点。每一页都套用下面的规则：

### 配色

- 按主题选**有态度的配色**，不要默认蓝。一个主色占 60-70% 视觉权重 +
  1 个辅助色 + 1 个锐利强调色，全篇统一。参考（主/辅/强调）：
  深夜商务 `1E2761/CADCFC/FFFFFF`、森林 `2C5F2D/97BC62/F5F5F5`、
  珊瑚活力 `F96167/F9E795/2F3C7E`、陶土 `B85042/E7E8D1/A7BEAE`、
  炭黑极简 `36454F/F2F2F2/212121`、青碧信任 `028090/00A896/02C39A`、
  酒红 `990011/FCF6F5/2F3C7E`、莓果 `6D2E46/A26769/ECE2D0`。
- 封面/结尾用深色底、内容页用浅色底（三明治结构），或全篇深色走高级感。
- 内容页背景用白色或极浅的主色淡色（如主色 + `fillTransparency: 92`
  的全幅 rect），不要米黄/奶油底。

### 版式（每页从这些模式里选，相邻页换着用）

- **卡片网格**：2×2 或 1×3 张 `roundRect` 卡片（浅色 fill 或深底 +
  `fillTransparency` 80-90），卡内「小标题 + 一句话」，要点 ≤ 4 条时
  永远优先用卡片而不是项目符号列表。
- **大数字标版**：关键指标用 54-72pt 超大数字 + 12-14pt 灰色小标签，
  一行放 2-4 组；比表格和句子有冲击力得多。
- **左右分栏**：左侧文字右侧图表/图片（约 5:7 或 7:5），别让图表孤零零
  贴在角落。
- **对比双栏**：之前/之后、方案 A/B，用两张对色卡片。
- **半版色块**：左或右 40% 画布放一整块主色 rect（里面放白字大标题），
  另一侧放内容。
- 每页必须有至少一个**视觉元素**（色块卡片/图表/大数字/图片），
  纯文字页禁止出现。

### 排版细节

- 标题 30-40pt 粗体，正文 14-16pt，注释 11-12pt 灰色；标题和正文的
  字号差要拉开（至少 2 倍）。
- 正文和列表**永远左对齐**，只有封面标题可以居中。
- 页边距 ≥ 0.6 英寸；卡片间距统一用 0.3 或 0.4 英寸，不要忽宽忽窄。
- 内容要撑满画布：一页只有一小段文字时，放大字号、加卡片或并页，
  不要留大片空白。
- 中文正文推荐 `微软雅黑`；数字/英文可不设 font 用默认。
- 文本估算溢出（text_overflow error）时：精简文字、调小字号或加大容器，
  不要硬塞。

### 图表

- 有数据一律用原生 chart，别写成文字或表格；单序列隐藏图例噪音的
  办法是把 series name 起成图表主题本身。
- 图表配色：用了 style 就省略 color（自动用风格 accents）；没用 style
  才手动指定 series 的 `color`，别用默认色板混搭。
- 图表至少占 4×3 英寸，旁边配一句结论文字（「营收三年翻三倍」），
  别让读者自己找重点。

### 禁止清单（AI 味的来源，逐条检查）

- **禁止标题下画横线/色条**（包括页顶色带、侧边竖条、卡片单边描边）——
  这是 AI 生成幻灯片最明显的特征；分隔靠留白和背景色差。
- 禁止整篇每页都是「标题 + 项目符号」的同一版式；相邻页必须换版式。
- 禁止正文居中；禁止低对比（浅底浅字/深底深字）。
- 禁止只给一页上设计、其余全裸奔——风格要贯穿全篇。

## 失败模式 QA（8 条规则 + 修复顺序铁律）

`pptx_check` / `pptx_render` 返回 `qa: { errors: [...], warnings: [...] }`
与 `structure: { errors: [...] }`（导出包结构自检，正常恒为空，非空说明
生成器有 bug，照报告反馈）。qa 每条含 rule、slide/element 序号与修正建议：

- `out_of_bounds`（error）：元素超出画布 → 调坐标/尺寸。
- `text_overflow`（error）：文本估算溢出容器 → 精简文字、调小字号或
  加大容器，不要硬塞。
- `font_too_small`（warning）：字号 <12pt → 提字号或删内容。
- `over_density`（warning）：单页 >12 个元素 → 拆页。
- `underfill`（warning）：空白页，或内容页纯文本 <20 字且无图表/表格/
  图片 → 补支撑内容或并入相邻页。
- `support_collapse`（warning）：grid/columns/hierarchy 卡片 <3，或
  卡片类型全部相同 → 补卡片/混卡片类型。
- `anchor_overexpansion`（warning）：手写坐标页单元素占画布 >65%
  （非满幅背景）→ 缩小锚点元素，给支撑内容留空间。
- `deck_rhythm_clone`（warning）：连续 3 页同一内容布局 → 换布局
  制造节奏。

**修复顺序铁律**：先内容（文字对不对、够不够）→ 再支撑（数据/图表/
卡片）→ 再视觉锚点（大数字/图片/色块的大小位置）→ 最后装饰。
顺序反了会来回返工。errors 必须修完才能导出（不要用 force 绕过）；
warnings 酌情优化。按报告逐条改 deck 源再重查，直到 errors 为空。
''',
);
