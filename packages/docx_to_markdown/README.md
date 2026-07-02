# docx_to_markdown

纯 Dart 的 DOCX → Markdown 转换器（知识库 P3e 本地解析轨，见 `docs/知识库功能-设计构想.md` §5.2）。

解压 OOXML 包并遍历 `word/document.xml`：

- 标题（`Heading1..9` / `Title` 段落样式 → `#`）
- 粗体 / 斜体 / 删除线 run
- 超链接（经 `word/_rels/document.xml.rels` 解析外部 URL）
- 无序 / 有序列表（经 `word/numbering.xml` 判定 numFmt，支持嵌套）
- 表格（首行作表头，`|` 转义）
- 换行（`w:br` / `w:cr`）与制表符

其余构造降级为纯文本。零 Flutter 依赖，同步 API，大文档请放进 isolate 跑：

```dart
import 'package:docx_to_markdown/docx_to_markdown.dart';

final markdown = DocxToMarkdown.convert(bytes); // Uint8List
// Flutter 中：await compute(DocxToMarkdown.convert, bytes);
```

无效包（非 zip / 缺 `word/document.xml`）抛 `DocxParseException`。
