import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/search/chat_search.dart';

part 'chat_search_controller.g.dart';

/// Application layer for 聊天搜索 (port of the web `useChatSearch` hook +
/// `ChatSearchService` wiring). The pure search logic lives in the domain
/// ([runChatSearch]); here we fetch the full topic / message / block sets
/// through [ChatRepository] and persist the recent-search list.

/// The key/value setting key holding the recent-search history (port of the
/// web `localStorage` key `chat-search-recent`).
const String kChatSearchRecentSettingKey = 'chat-search-recent';
const int _recentSearchLimit = 8;

/// A single search invocation: the raw query plus the AND/OR mode. Acts as the
/// family key for [chatSearchResults], so it overrides `==` / `hashCode` to
/// keep the provider cached per distinct request.
class ChatSearchRequest {
  const ChatSearchRequest({required this.query, required this.mode});

  final String query;
  final ChatSearchMode mode;

  @override
  bool operator ==(Object other) =>
      other is ChatSearchRequest && other.query == query && other.mode == mode;

  @override
  int get hashCode => Object.hash(query, mode);
}

/// Runs a full-database search for [request]. Returns an empty result set for a
/// blank query without touching the database.
@riverpod
Future<ChatSearchResultSet> chatSearchResults(
  Ref ref,
  ChatSearchRequest request,
) async {
  if (request.query.trim().isEmpty) return ChatSearchResultSet.empty;
  final repo = ref.watch(chatRepositoryProvider);
  final topics = await repo.getAllTopics();
  final messages = await repo.getAllMessages();
  final blocks = await repo.getAllMessageBlocks();
  return runChatSearch(
    rawQuery: request.query,
    topics: topics,
    messages: messages,
    blocks: blocks,
    mode: request.mode,
  );
}

/// The recent-search history, newest first, capped at [_recentSearchLimit] and
/// persisted via [ChatRepository]'s key/value store (port of the web
/// `useChatSearch` `localStorage` handling).
@Riverpod(keepAlive: true)
class ChatSearchRecent extends _$ChatSearchRecent {
  @override
  List<String> build() {
    _hydrate();
    return const <String>[];
  }

  Future<void> _hydrate() async {
    final raw = await ref
        .read(chatRepositoryProvider)
        .getSetting(kChatSearchRecentSettingKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        state = decoded.whereType<String>().toList();
      }
    } on FormatException {
      // Corrupt value — ignore and keep the empty default.
    }
  }

  /// Adds [query] to the front (de-duplicated, trimmed) and persists.
  void add(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final next = <String>[
      trimmed,
      ...state.where((q) => q != trimmed),
    ].take(_recentSearchLimit).toList();
    state = next;
    _persist(next);
  }

  void remove(String query) {
    final next = state.where((q) => q != query).toList();
    state = next;
    _persist(next);
  }

  void clear() {
    state = const <String>[];
    _persist(const <String>[]);
  }

  void _persist(List<String> list) {
    ref
        .read(chatRepositoryProvider)
        .saveSetting(kChatSearchRecentSettingKey, jsonEncode(list));
  }
}
