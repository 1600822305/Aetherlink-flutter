/// Prompt-injection (提示词注入) plumbing for MCP tools — the Dart port of the
/// web `mcpPrompt.ts` + `mcpToolParser.ts` pieces used when the provider has no
/// native function calling (or the user picks 提示词注入 mode).
///
/// Instead of a wire-level `tools` field, the tool catalogue is described inside
/// the system prompt as an XML protocol; the model answers with `<tool_use>`
/// blocks in its plain text, which [parseToolUseBlocks] extracts, and results
/// are fed back as `<tool_use_result>` blocks built by [formatToolUseResult].
library;

import 'dart:convert';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// The system-prompt template (verbatim port of the web `SYSTEM_PROMPT`) with
/// `{{ AVAILABLE_TOOLS }}`, `{{ TOOL_USE_EXAMPLES }}` and
/// `{{ USER_SYSTEM_PROMPT }}` placeholders filled by [buildMcpSystemPrompt].
const String _kSystemPrompt = '''
You are a helpful assistant with access to external tools. Use them when needed to fulfill the user's request.

# Tool Calling Protocol

You may call **one tool per response**. After calling a tool, wait for the result before proceeding.

## Format

To call a tool, output the following XML block:

<tool_use>
<name>TOOL_NAME</name>
<arguments>JSON_OBJECT</arguments>
</tool_use>

- **TOOL_NAME**: Must exactly match one of the available tool names listed below.
- **JSON_OBJECT**: A valid JSON object with the required parameters.

Tool results will be returned as:

<tool_use_result>
<name>TOOL_NAME</name>
<result>RESULT_CONTENT</result>
</tool_use_result>

Use the result to inform your next step: call another tool or provide a final answer.

## Available Tools
{{ AVAILABLE_TOOLS }}

## Rules

1. **Only call tools listed above.** Never invent tool names or call tools that are not in the list.
2. **One tool call per message.** Do not output multiple `<tool_use>` blocks in a single response.
3. **Use correct argument types.** Pass actual values, not variable names or placeholders.
4. **Do not repeat identical calls.** If you already called a tool with the same parameters, use the previous result.
5. **Call tools only when necessary.** If you can answer directly from your knowledge, do so without calling a tool.
6. **Always use the exact XML format.** Any deviation will cause a parsing failure.
7. **When providing a final answer after tool use, do not include `<tool_use>` tags.**

## Examples
{{ TOOL_USE_EXAMPLES }}

## User Instructions
{{ USER_SYSTEM_PROMPT }}
''';

/// Illustrative `<tool_use>` exchanges (verbatim port of web `ToolUseExamples`).
const String _kToolUseExamples = '''
Below are illustrative examples using hypothetical tools. Your actual available tools are listed in the "Available Tools" section.

### Example 1: Single tool call

User: What is 1024 * 768?

Assistant: 
<tool_use>
<name>calculator</name>
<arguments>{"expression": "1024 * 768"}</arguments>
</tool_use>

User:
<tool_use_result>
<name>calculator</name>
<result>786432</result>
</tool_use_result>

Assistant: 1024 × 768 = 786,432.

### Example 2: No tool needed

User: What is the capital of France?

Assistant: The capital of France is Paris.
''';

/// Builds the system prompt for 提示词注入 mode: when [tools] is empty this is
/// just [userSystemPrompt] (port of the web `buildSystemPrompt` early return);
/// otherwise the tool catalogue is rendered into the [_kSystemPrompt] template.
String buildMcpSystemPrompt(
  String? userSystemPrompt,
  List<McpToolDefinition> tools,
) {
  final user = userSystemPrompt ?? '';
  if (tools.isEmpty) return user;
  return _kSystemPrompt
      .replaceFirst('{{ AVAILABLE_TOOLS }}', _availableTools(tools))
      .replaceFirst('{{ TOOL_USE_EXAMPLES }}', _kToolUseExamples)
      .replaceFirst('{{ USER_SYSTEM_PROMPT }}', user);
}

/// Renders [tools] into the `<tools>…</tools>` XML block (port of the web
/// `AvailableTools`): one `<tool>` per entry with name, description and, when
/// the JSON schema lists `properties`, a `<parameters>` list flagging each
/// argument `(required)` / `(optional)` with its description or type.
String _availableTools(List<McpToolDefinition> tools) {
  final entries = tools
      .map((tool) {
        final schema = tool.inputSchema;
        final properties = schema['properties'];
        var paramsBlock = '';
        if (properties is Map<String, Object?> && properties.isNotEmpty) {
          final required = <String>{
            ...?(schema['required'] as List<Object?>?)?.whereType<String>(),
          };
          final params = properties.entries
              .map((e) {
                final reqTag = required.contains(e.key)
                    ? ' (required)'
                    : ' (optional)';
                final val = e.value;
                final desc = val is Map<String, Object?>
                    ? (val['description'] ?? val['type'] ?? 'any')
                    : 'any';
                return '    - ${e.key}$reqTag: $desc';
              })
              .join('\n');
          paramsBlock = '\n  <parameters>\n$params\n  </parameters>';
        }
        final description = tool.description.isEmpty
            ? 'No description'
            : tool.description;
        return '<tool>\n  <name>${tool.name}</name>\n  '
            '<description>$description</description>$paramsBlock\n</tool>';
      })
      .join('\n');
  return '<tools>\n$entries\n</tools>';
}

/// A `<tool_use>` block extracted from a prompt-injection response: the
/// model-chosen [name] and the raw [arguments] JSON string (decoded by the
/// caller at execution time, matching how function-calling [LlmToolCall]s ride).
typedef ParsedToolUse = ({String name, String arguments});

/// Pattern matching one `<tool_use>` block (port of the web `parseToolUse`
/// `toolUsePattern`); `dotAll` lets `.` span the newlines inside a block.
final RegExp _toolUsePattern = RegExp(
  r'<tool_use>.*?<name>(.*?)</name>.*?<arguments>(.*?)</arguments>.*?</tool_use>',
  dotAll: true,
);

/// Extracts the `<tool_use>` calls from a prompt-injection [content] string,
/// keeping only those whose name matches one of [tools] (hallucinated names are
/// dropped, mirroring the web `findMcpToolByName` guard). [arguments] is the
/// trimmed raw JSON exactly as the model wrote it.
List<ParsedToolUse> parseToolUseBlocks(
  String content,
  List<McpToolDefinition> tools,
) {
  if (content.isEmpty || tools.isEmpty) return const [];
  final known = tools.map((t) => t.name).toSet();
  final calls = <ParsedToolUse>[];
  for (final match in _toolUsePattern.allMatches(content)) {
    final name = match.group(1)!.trim();
    if (!known.contains(name)) continue;
    calls.add((name: name, arguments: match.group(2)!.trim()));
  }
  return calls;
}

/// Builds the `<tool_use_result>` block fed back as the next user turn in
/// 提示词注入 mode (port of the web result protocol). [result] is the tool's
/// text payload (already a JSON string for the built-ins).
String formatToolUseResult(String name, String result) {
  return '<tool_use_result>\n<name>$name</name>\n<result>$result</result>\n'
      '</tool_use_result>';
}

/// Strips any `<tool_use>` blocks from [content] so the persisted assistant
/// text doesn't show the raw XML protocol (port of the web `removeToolUseTags`
/// format-1 branch). Used when rendering the prompt-injection turn that carried
/// the call.
String removeToolUseTags(String content) {
  return content
      .replaceAll(RegExp(r'<tool_use>.*?</tool_use>', dotAll: true), '')
      .trim();
}

/// Encodes [arguments] (a record's raw JSON string) into the map the built-in
/// tool runner expects, tolerating an empty/blank string (→ `{}`) or non-object
/// JSON (→ `{}`), matching the adapters' decode of function-calling arguments.
Map<String, Object?> decodeToolArguments(String arguments) {
  if (arguments.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(arguments);
    return decoded is Map<String, Object?> ? decoded : const {};
  } on FormatException {
    return const {};
  }
}
