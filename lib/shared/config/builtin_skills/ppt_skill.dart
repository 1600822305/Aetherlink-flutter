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
  version: '1.2.0',
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

## 设计规范

- 每页一个主题；正文字号 ≥ 14pt、标题 28-44pt、页脚/注释 ≥ 12pt。
- 留白：内容区四周至少留 0.6-0.8 英寸边距；每页元素 ≤ 12 个。
- 配色：选一个主色 + 1-2 个强调色，深色底配浅色字（反之亦然），
  全篇统一；标题下可用一条细 line 或色块作视觉锚点。
- 文本估算溢出（text_overflow error）时：精简文字、调小字号或加大容器，
  不要硬塞。
- 中文正文推荐 `微软雅黑`；数字/英文可不设 font 用默认。

## QA 报告的用法

`pptx_check` / `pptx_render` 返回 `qa: { errors: [...], warnings: [...] }`，
每条含 rule（out_of_bounds / text_overflow / font_too_small /
over_density / underfill）、slide/element 序号与修正建议。errors 必须
修完才能导出（不要用 force 绕过）；warnings 酌情优化。按报告逐条改
deck 源再重查，直到 errors 为空。
''',
);
