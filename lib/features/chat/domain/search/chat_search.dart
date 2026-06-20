import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Pure-Dart 聊天搜索 logic — a 1:1 port of the web search layer
/// (`src/shared/services/search/queryUtils.ts` + `ChatSearchService.ts`).
///
/// Stays framework-free (no Flutter / Riverpod / Drift) so it can be unit
/// tested and lives in `domain`. The application layer fetches the full
/// topic / message / block sets through [ChatRepository] and hands them to
/// [runChatSearch]; everything below is case-insensitive substring matching,
/// which also covers Chinese (no word segmentation — the whole phrase is one
/// keyword), exactly like the web.

/// AND = every term must match; OR = any term matches.
enum ChatSearchMode { and, or }

/// Whether a hit came from a topic title or a message body.
enum ChatSearchHitKind { topic, message }

// Scoring weights (ported verbatim from `ChatSearchService.ts`).
const int kChatSearchDefaultMaxResults = 300;
const int kChatSearchSnippetLength = 150;
const int _scoreTopicBase = 1000;
const int _scoreMessageBase = 500;
const int _scorePerOccurrence = 10;
const int _scoreOccurrenceCap = 100;

/// A `[start, end)` highlight range within a snippet (returned instead of HTML
/// so rendering stays injection-safe).
class MatchRange {
  const MatchRange(this.start, this.end);

  final int start;
  final int end;
}

/// A parsed query: the raw input, the free keywords, and the quoted phrases.
class ParsedQuery {
  const ParsedQuery({
    required this.raw,
    required this.keywords,
    required this.phrases,
  });

  final String raw;
  final List<String> keywords;
  final List<String> phrases;

  /// All searchable terms (phrases first, then keywords).
  List<String> get terms => <String>[...phrases, ...keywords];

  bool get isEmpty => keywords.isEmpty && phrases.isEmpty;
}

/// One search result. [createdAt] is the topic's / message's timestamp (drives
/// the secondary sort and the date grouping); [assistantId] lets the caller
/// switch to the owning assistant when jumping to the result.
class ChatSearchHit {
  const ChatSearchHit({
    required this.id,
    required this.kind,
    required this.topicId,
    required this.topicName,
    required this.snippet,
    required this.matchRanges,
    required this.createdAt,
    required this.score,
    this.assistantId,
    this.messageId,
    this.role,
  });

  final String id;
  final ChatSearchHitKind kind;
  final String topicId;
  final String? assistantId;
  final String topicName;
  final String? messageId;
  final MessageRole? role;
  final String snippet;
  final List<MatchRange> matchRanges;
  final DateTime createdAt;
  final int score;
}

/// The full outcome of a search: the (truncated) hits, the total before
/// truncation, whether it was truncated, and how long the scan took.
class ChatSearchResultSet {
  const ChatSearchResultSet({
    required this.hits,
    required this.total,
    required this.truncated,
    this.tookMs = 0,
  });

  static const ChatSearchResultSet empty = ChatSearchResultSet(
    hits: <ChatSearchHit>[],
    total: 0,
    truncated: false,
  );

  final List<ChatSearchHit> hits;
  final int total;
  final bool truncated;
  final int tookMs;
}

final RegExp _phrasePattern = RegExp('"([^"]+)"');
final RegExp _phraseStripPattern = RegExp('"[^"]*"');
final RegExp _whitespacePattern = RegExp(r'\s+');

/// Parses [raw] into quoted phrases plus whitespace-split keywords (port of the
/// web `parseQuery`).
ParsedQuery parseQuery(String raw) {
  final phrases = <String>[];
  for (final match in _phrasePattern.allMatches(raw)) {
    final phrase = match.group(1)!.trim().toLowerCase();
    if (phrase.isNotEmpty) phrases.add(phrase);
  }

  final remaining = raw.replaceAll(_phraseStripPattern, ' ');
  final keywords = <String>[];
  for (final word in remaining.split(_whitespacePattern)) {
    final w = word.trim().toLowerCase();
    if (w.isNotEmpty && !phrases.contains(w)) keywords.add(w);
  }

  return ParsedQuery(raw: raw, keywords: keywords, phrases: phrases);
}

/// Whether [text] matches [parsed] under [mode] (AND = all terms, OR = any).
bool isMatch(String text, ParsedQuery parsed, ChatSearchMode mode) {
  if (text.isEmpty) return false;
  final terms = parsed.terms;
  if (terms.isEmpty) return false;
  final lower = text.toLowerCase();
  if (mode == ChatSearchMode.and) {
    return terms.every(lower.contains);
  }
  return terms.any(lower.contains);
}

/// Total occurrences of every term in [text] (used for scoring).
int countOccurrences(String text, ParsedQuery parsed) {
  if (text.isEmpty) return 0;
  final lower = text.toLowerCase();
  var count = 0;
  for (final term in parsed.terms) {
    if (term.isEmpty) continue;
    var idx = lower.indexOf(term);
    while (idx != -1) {
      count += 1;
      idx = lower.indexOf(term, idx + term.length);
    }
  }
  return count;
}

/// All highlight ranges in [text], sorted by start and with overlaps merged.
List<MatchRange> computeMatchRanges(String text, ParsedQuery parsed) {
  if (text.isEmpty) return const <MatchRange>[];
  final lower = text.toLowerCase();
  final ranges = <MatchRange>[];
  for (final term in parsed.terms) {
    if (term.isEmpty) continue;
    var idx = lower.indexOf(term);
    while (idx != -1) {
      ranges.add(MatchRange(idx, idx + term.length));
      idx = lower.indexOf(term, idx + term.length);
    }
  }
  if (ranges.isEmpty) return const <MatchRange>[];
  ranges.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : a.end.compareTo(b.end);
  });
  final merged = <MatchRange>[ranges.first];
  for (var i = 1; i < ranges.length; i++) {
    final last = merged.last;
    final cur = ranges[i];
    if (cur.start <= last.end) {
      if (cur.end > last.end) {
        merged[merged.length - 1] = MatchRange(last.start, cur.end);
      }
    } else {
      merged.add(cur);
    }
  }
  return merged;
}

/// A snippet centered on the first match plus the ranges within that snippet.
typedef SearchSnippet = ({String snippet, List<MatchRange> ranges});

/// Extracts a [maxLength]-bounded snippet centered on the first match, prefixed
/// / suffixed with `…` when truncated (port of the web `buildSnippet`).
SearchSnippet buildSnippet(
  String text,
  ParsedQuery parsed, {
  int maxLength = kChatSearchSnippetLength,
}) {
  if (text.isEmpty) return (snippet: '', ranges: const <MatchRange>[]);

  if (text.length <= maxLength) {
    return (snippet: text, ranges: computeMatchRanges(text, parsed));
  }

  final lower = text.toLowerCase();
  var firstIdx = -1;
  var firstTermLen = 0;
  for (final term in parsed.terms) {
    if (term.isEmpty) continue;
    final idx = lower.indexOf(term);
    if (idx != -1 && (firstIdx == -1 || idx < firstIdx)) {
      firstIdx = idx;
      firstTermLen = term.length;
    }
  }

  if (firstIdx == -1) {
    return (
      snippet: '${text.substring(0, maxLength)}…',
      ranges: const <MatchRange>[],
    );
  }

  final center = firstIdx + firstTermLen ~/ 2;
  final half = maxLength ~/ 2;
  var start = center - half < 0 ? 0 : center - half;
  final end = start + maxLength < text.length ? start + maxLength : text.length;
  if (end - start < maxLength && start > 0) {
    start = end - maxLength < 0 ? 0 : end - maxLength;
  }

  var snippet = text.substring(start, end);
  if (start > 0) snippet = '…$snippet';
  if (end < text.length) snippet = '$snippet…';

  return (snippet: snippet, ranges: computeMatchRanges(snippet, parsed));
}

class _TopicMeta {
  const _TopicMeta({
    required this.name,
    required this.createdAt,
    this.assistantId,
  });

  final String name;
  final DateTime createdAt;
  final String? assistantId;
}

int _occurrenceScore(String text, ParsedQuery parsed) {
  final raw = countOccurrences(text, parsed) * _scorePerOccurrence;
  return raw > _scoreOccurrenceCap ? _scoreOccurrenceCap : raw;
}

/// Runs a full search over [topics] / [messages] / [blocks], scoring topic
/// titles (base 1000) and message bodies (base 500), sorting by score then
/// recency, and truncating to [maxResults] — the port of
/// `ChatSearchService.search`. Only `main_text` blocks are scanned, matching
/// the web. Scoring happens before truncation so the most relevant hits
/// survive.
ChatSearchResultSet runChatSearch({
  required String rawQuery,
  required List<Topic> topics,
  required List<Message> messages,
  required List<MessageBlock> blocks,
  ChatSearchMode mode = ChatSearchMode.and,
  int maxResults = kChatSearchDefaultMaxResults,
}) {
  final parsed = parseQuery(rawQuery);
  if (parsed.isEmpty) return ChatSearchResultSet.empty;

  final stopwatch = Stopwatch()..start();

  final topicMeta = <String, _TopicMeta>{
    for (final topic in topics)
      topic.id: _TopicMeta(
        name: topic.name.isNotEmpty ? topic.name : '未命名话题',
        createdAt: topic.createdAt,
        assistantId: topic.assistantId,
      ),
  };

  final hits = <ChatSearchHit>[];

  topicMeta.forEach((topicId, meta) {
    if (!isMatch(meta.name, parsed, mode)) return;
    final snippet = buildSnippet(meta.name, parsed);
    hits.add(
      ChatSearchHit(
        id: 'topic-$topicId',
        kind: ChatSearchHitKind.topic,
        topicId: topicId,
        assistantId: meta.assistantId,
        topicName: meta.name,
        snippet: snippet.snippet,
        matchRanges: snippet.ranges,
        createdAt: meta.createdAt,
        score: _scoreTopicBase + _occurrenceScore(meta.name, parsed),
      ),
    );
  });

  final messageMeta =
      <String, ({String topicId, MessageRole role, DateTime createdAt})>{
        for (final message in messages)
          if (topicMeta.containsKey(message.topicId))
            message.id: (
              topicId: message.topicId,
              role: message.role,
              createdAt: message.createdAt,
            ),
      };

  final seenMessageIds = <String>{};
  for (final block in blocks) {
    if (block is! MainTextBlock) continue;
    final content = block.content;
    final meta = messageMeta[block.messageId];
    if (content.isEmpty ||
        meta == null ||
        seenMessageIds.contains(block.messageId) ||
        !isMatch(content, parsed, mode)) {
      continue;
    }
    seenMessageIds.add(block.messageId);
    final snippet = buildSnippet(content, parsed);
    final topic = topicMeta[meta.topicId];
    hits.add(
      ChatSearchHit(
        id: 'message-${block.messageId}',
        kind: ChatSearchHitKind.message,
        topicId: meta.topicId,
        assistantId: topic?.assistantId,
        topicName: topic?.name ?? '未命名话题',
        messageId: block.messageId,
        role: meta.role,
        snippet: snippet.snippet,
        matchRanges: snippet.ranges,
        createdAt: meta.createdAt,
        score: _scoreMessageBase + _occurrenceScore(content, parsed),
      ),
    );
  }

  hits.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : b.createdAt.compareTo(a.createdAt);
  });

  final total = hits.length;
  final truncated = total > maxResults;
  return ChatSearchResultSet(
    hits: truncated ? hits.sublist(0, maxResults) : hits,
    total: total,
    truncated: truncated,
    tookMs: (stopwatch..stop()).elapsedMilliseconds,
  );
}
