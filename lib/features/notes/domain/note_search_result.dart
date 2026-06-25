import 'package:flutter/foundation.dart';

import 'package:aetherlink_flutter/features/notes/domain/note_node.dart';

/// Where a search keyword was found within a note.
enum NoteMatchType { filename, content, both }

/// A single in-content match with surrounding context, used to render a
/// highlighted snippet under a search result.
@immutable
class NoteSearchMatch {
  const NoteSearchMatch({
    required this.lineNumber,
    required this.context,
    required this.matchStart,
    required this.matchEnd,
  });

  /// 1-based line number of the match.
  final int lineNumber;

  /// The context snippet (may be prefixed/suffixed with an ellipsis).
  final String context;

  /// Match offsets *within* [context] for highlighting.
  final int matchStart;
  final int matchEnd;
}

/// A full-text search hit: a note (file) plus how/where it matched and a
/// relevance score. Mirrors Cherry Studio's `SearchResult` shape.
@immutable
class NoteSearchResult {
  const NoteSearchResult({
    required this.node,
    required this.matchType,
    required this.score,
    this.matches = const <NoteSearchMatch>[],
  });

  final NoteNode node;
  final NoteMatchType matchType;
  final int score;
  final List<NoteSearchMatch> matches;
}
