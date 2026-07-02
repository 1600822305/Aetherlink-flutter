# pdf_to_markdown

基于 pdfrx_engine（PDFium，BSD-3-Clause 开源）的 PDF → 文本转换器（知识库 P3e 本地解析轨，见 `docs/知识库功能-设计构想.md` §5.2）。

逐页 `loadStructuredText()` 抽取文本层（PDFium 已做阅读顺序/行切分），再用启发式重排：

- 英文断词连字符还原（`imple-` + `mentation` → `implementation`）
- 硬换行的行合并成段落（CJK 直接拼接、英文以空格连接，句末标点结束段落）
- 列表行保持独立，`•` 归一为 `-`
- 页间空行分隔，空页跳过

局限：PDFium 文本层没有字号/样式语义，暂不产出 Markdown 标题；扫描件（无文本层）
返回空字符串，由调用方提示走云端 OCR 轨。

零 Flutter 依赖，可在纯 Dart / 服务端使用。调用前需完成 PDFium 初始化：

```dart
import 'package:pdf_to_markdown/pdf_to_markdown.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';

await pdfrxInitialize(); // Flutter 应用改用 pdfrx 插件的 pdfrxFlutterInitialize()
final text = await PdfToMarkdown.convert(bytes); // Uint8List
```

打开失败（损坏/加密）抛 `PdfParseException`。

单测：`dart test`（`converter_test.dart` 首次运行会下载宿主平台的 PDFium 动态库）。
