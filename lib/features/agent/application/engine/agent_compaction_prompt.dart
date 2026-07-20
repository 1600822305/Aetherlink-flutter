/// 压缩摘要提示词与输出解析（压缩升级计划 ②，对标 Claude Code
/// `services/compact/prompt.ts`）：结构化摘要——模型先在 `<analysis>`
/// 块里逐段梳理，再输出 `<summary>` 正文；`<analysis>` 是草稿纸，
/// 落库前剥离。纯常量 + 纯函数，独立于执行层便于单测。
library;

/// 压缩摘要的系统提示词（CC BASE_COMPACT_PROMPT 的中文对齐版）。
const String kCompactionSummarySystemPrompt = '''
重要：只输出纯文本，不要调用任何工具。你的任务是把下面这段智能体执行过程压缩成
一份详尽的摘要，供后续循环替代原文继续任务。摘要必须完整保留继续开发所需的
技术细节、代码模式与架构决策。

先把你的分析写在 <analysis> 标签里，逐段梳理对话，确保覆盖：
- 用户的明确请求与意图；
- 你处理请求的思路与关键决策；
- 具体细节：文件名、完整代码片段、函数签名、文件改动；
- 遇到的报错及修复方式，特别注意用户给过的纠正性反馈。

然后把最终摘要写在 <summary> 标签里，包含以下小节：

1. 用户请求与意图：详细记录用户所有明确请求与约束。
2. 关键概念：涉及的技术、框架与架构要点。
3. 文件与代码：查看/修改/新建的具体文件，附重要代码片段与其意义。
4. 报错与修复：所有报错及修复方式，特别是用户的纠正性反馈。
5. 已解决的问题：已解决事项与仍在排查的问题。
6. 用户消息记录：列出全部非工具结果的用户消息（理解意图变化的关键）。
7. 待办事项：用户明确要求但尚未完成的任务。
8. 当前工作：摘要请求前正在做的事，附文件名与代码片段。
9. 下一步（可选）：与最近工作直接相关的下一步；必须与用户最近的明确请求
   一致，不要自行开启新任务；如有，引用最近对话原文说明做到了哪里。

输出格式：<analysis>…</analysis> 换行后 <summary>…</summary>，不要其他文字。''';

/// 从模型输出提取摘要正文：剥离 `<analysis>` 草稿块，解包 `<summary>`
/// 标签；模型未按格式输出时（无标签）原样返回修剪后的全文，保证
/// 摘要永不因格式问题丢失。
String extractCompactionSummary(String raw) {
  var text = raw;
  final analysisStart = text.indexOf('<analysis>');
  if (analysisStart >= 0) {
    final analysisEnd = text.indexOf('</analysis>', analysisStart);
    text = analysisEnd >= 0
        ? text.substring(0, analysisStart) +
            text.substring(analysisEnd + '</analysis>'.length)
        : text.substring(0, analysisStart);
  }
  final summaryStart = text.indexOf('<summary>');
  if (summaryStart >= 0) {
    final bodyStart = summaryStart + '<summary>'.length;
    final summaryEnd = text.indexOf('</summary>', bodyStart);
    text = summaryEnd >= 0
        ? text.substring(bodyStart, summaryEnd)
        : text.substring(bodyStart);
  }
  return text.trim();
}
