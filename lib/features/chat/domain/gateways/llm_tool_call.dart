/// A provider-neutral tool call parsed from a model response — the port of the
/// web `MCPToolResponse`'s call shape (`{ id, tool.name, arguments }`).
///
/// Function-calling mode carries the provider-issued [id] (OpenAI
/// `tool_call_id` / Anthropic `tool_use` id) so the result can be linked back
/// to the call; prompt-injection mode has no id (the model emits an XML
/// `<tool_use>` block), so [id] is empty and results are matched by [name].
/// [arguments] is the raw JSON string exactly as the model produced it (OpenAI
/// streams it char-by-char, Anthropic via `input_json_delta`); callers decode
/// it to a map at execution time.
class LlmToolCall {
  const LlmToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final String arguments;
}
