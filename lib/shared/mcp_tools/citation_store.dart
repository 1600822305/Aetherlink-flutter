/// A simple in-memory store mapping citation IDs to their source URLs.
/// Populated by [runWebSearchTool] when search results arrive, consumed
/// by the citation tap handler in the message bubble.
library;

final Map<String, String> _citations = {};

/// Records a citation [id] → [url] mapping.
void storeCitation(String id, String url) {
  _citations[id] = url;
}

/// Looks up the source URL for a citation [id].
String? lookupCitationUrl(String id) => _citations[id];

/// Clears all stored citations (e.g. on topic switch).
void clearCitations() => _citations.clear();
