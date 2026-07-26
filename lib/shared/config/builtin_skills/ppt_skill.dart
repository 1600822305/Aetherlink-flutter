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
  version: '1.3.0',
  author: 'AetherLink',
  enabled: true,
  content: '''
## 能力概览

`@aether/pptx` 把结构化 deck.json 源渲染成**原生可编辑**的 .pptx
（文本框/形状/图片/表格/图表都是原生 PowerPoint 对象，不是截图）。两个工具：

- `pptx_check`：校验 deck 源 + 布局 QA（不写文件，免审批）。
- `pptx_render`：QA 通过后导出 .pptx 到工作区（需用户确认）；
  可传 `preview: true` 同时导出 .preview.html 预览。

## 标准工作流

1. 先和用户对齐：主题、页数、风格（深色/浅色、正式/活泼）、语言。
2. 写大纲（每页一句话），再逐页展开成 deck.json。
3. `pptx_check` 自检 → 按返回的 errors/warnings 修改源 → 重查。
4. 通过后 `pptx_render` 导出（路径如 `演示文稿/主题.pptx`）。
5. 同时用 file-editor 的 `write` 把 deck 源存为同名 `主题.deck.json`：
   用户在工作区点开它可直接预览幻灯片（编辑器右上角「PPT 预览」），
   后续修改也从这份源迭代。

## deck.json 源格式

坐标单位**英寸**，16x9 画布为 13.33 × 7.5（4x3 为 10 × 7.5）。

```json
{
  "layout": "16x9",
  "title": "文件标题",
  "slides": [
    {
      "background": "0F1115",
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
  `ellipse` / `line`（h 可为 0，用 lineColor+lineWidth）。
- align：left/center/right；valign：top/middle/bottom。
- chart 取值：`bar` / `line` / `pie`（导出为原生 OOXML 图表，可在
  PowerPoint 里改样式）；每个 series 的 values 长度必须等于
  categories 长度；饼图只支持 1 个 series；color 省略时用默认色板。

## 硬性规则（违反会被拒绝或产出损坏文件）

- 颜色一律 **6 位 hex**（如 `1A73E8`），不带 `#`、不带 alpha；
  透明度用独立的 `fillTransparency`（0-100）。
- 列表用 `bullet: true` + `indentLevel`（0-8），**不要**把 `•` 写进正文。
- 图片 data 必须是 PNG 或 JPEG 的 base64。
- 表格每行列数必须一致。
- 所有元素不得超出画布（QA 会报 out_of_bounds error）。

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
- 图表配色用全篇主色/强调色（series 的 `color`），别用默认色板混搭。
- 图表至少占 4×3 英寸，旁边配一句结论文字（「营收三年翻三倍」），
  别让读者自己找重点。

### 禁止清单（AI 味的来源，逐条检查）

- **禁止标题下画横线/色条**（包括页顶色带、侧边竖条、卡片单边描边）——
  这是 AI 生成幻灯片最明显的特征；分隔靠留白和背景色差。
- 禁止整篇每页都是「标题 + 项目符号」的同一版式；相邻页必须换版式。
- 禁止正文居中；禁止低对比（浅底浅字/深底深字）。
- 禁止只给一页上设计、其余全裸奔——风格要贯穿全篇。

## QA 报告的用法

`pptx_check` / `pptx_render` 返回 `qa: { errors: [...], warnings: [...] }`，
每条含 rule（out_of_bounds / text_overflow / font_too_small /
over_density / underfill）、slide/element 序号与修正建议。errors 必须
修完才能导出（不要用 force 绕过）；warnings 酌情优化。按报告逐条改
deck 源再重查，直到 errors 为空。
''',
);
