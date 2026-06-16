import 'package:aetherlink_flutter/shared/domain/model.dart';

/// The wire protocols M2 supports. Vendors are grouped by protocol, not one
/// adapter per vendor: every OpenAI-compatible vendor (OpenAI, DashScope, Grok,
/// DeepSeek, Moonshot, OpenRouter, Ollama, …) shares [openaiCompatible] and
/// differs only by config (ADR-0006).
enum LlmProtocol { openaiCompatible, anthropic, gemini }

/// Resolves a [Model] to its wire protocol from `providerType` (falling back to
/// `provider`). Anything unrecognised maps to [LlmProtocol.openaiCompatible],
/// since the OpenAI-compatible surface is the de-facto standard and the place
/// the long tail of vendors lives.
LlmProtocol protocolForModel(Model model) =>
    protocolForProviderKey(model.providerType ?? model.provider);

/// Resolves a raw provider key (`providerType` / `provider`) to its protocol.
/// Shared by [protocolForModel] and the model-catalog lookup, which has no
/// concrete [Model] yet.
LlmProtocol protocolForProviderKey(String key) {
  final normalized = key.toLowerCase();
  if (normalized == 'anthropic' || normalized == 'claude') {
    return LlmProtocol.anthropic;
  }
  if (normalized == 'gemini' || normalized == 'google') {
    return LlmProtocol.gemini;
  }
  return LlmProtocol.openaiCompatible;
}
