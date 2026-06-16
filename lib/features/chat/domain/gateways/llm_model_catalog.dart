/// A discovered model from a provider's catalog endpoint (the `自动获取模型`
/// feature). Pure-Dart value object owned by `domain`; `data` builds these from
/// each protocol's list-models response and the UI maps them onto a persisted
/// `Model`.
class LlmModelInfo {
  const LlmModelInfo({
    required this.id,
    this.name,
    this.ownedBy,
    this.description,
  });

  /// The model id used in chat requests (e.g. `gpt-4o`).
  final String id;

  /// A human-friendly label when the endpoint supplies one; falls back to [id].
  final String? name;

  /// The owner/vendor when reported (e.g. `openai`, `google`).
  final String? ownedBy;

  final String? description;
}

/// The endpoint coordinates needed to list a provider's models, independent of
/// any single [Model]. Carried to [LlmModelCatalog] so it can pick the protocol
/// (from [providerType]) and authenticate without the caller touching `data`.
class LlmModelQuery {
  const LlmModelQuery({
    required this.providerType,
    this.apiKey,
    this.baseUrl,
    this.extraHeaders,
  });

  final String providerType;
  final String? apiKey;
  final String? baseUrl;
  final Map<String, String>? extraHeaders;
}

/// Lists the models a provider exposes. A sibling port to `LlmGateway`
/// (streaming) — kept separate so the streaming contract stays untouched.
/// Implemented in `data`; injected via the `app/di` seam so the UI depends only
/// on this port and tests can supply a fake.
abstract interface class LlmModelCatalog {
  Future<List<LlmModelInfo>> listModels(LlmModelQuery query);
}
