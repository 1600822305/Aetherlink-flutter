import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message_segment.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

/// Splices triggered 世界书 entries into a request (P2：无计时器语义).
///
/// - before / after system prompt: joined into the system string;
/// - top / bottom of chat and at-depth: inserted as whole messages **between
///   segments** only (one segment = one rendered view), so an assistant
///   `toolCalls` turn and its tool results — or a 提示词注入 `<tool_use>`
///   round — are never separated;
/// - mid-chat injections use only user / assistant roles (some adapters drop
///   mid-chat `system` messages); user content is wrapped in
///   `<system>…</system>` like kelivo.
///
/// [entries] must already be priority-sorted; that order is kept inside every
/// merged message. Nothing triggered → inputs come back unchanged.
///
/// [kWorldBookMergeAdjacentUser] is the production default for
/// `mergeAdjacentUser` (some legacy OpenAI-compatible endpoints reject two
/// consecutive user turns); the pure function itself defaults to `false`.
const bool kWorldBookMergeAdjacentUser = true;

abstract final class WorldBookInjector {
  /// [system] with the before / after-system entries joined in. A null or
  /// empty [system] yields just the world book text.
  static String? injectSystem(String? system, List<WorldBookEntry> entries) {
    final before = _join(entries, WorldBookInjectionPosition.beforeSystemPrompt);
    final after = _join(entries, WorldBookInjectionPosition.afterSystemPrompt);
    if (before.isEmpty && after.isEmpty) return system;
    final base = system ?? '';
    final parts = [
      if (before.isNotEmpty) before,
      if (base.isNotEmpty) base,
      if (after.isNotEmpty) after,
    ];
    return parts.join('\n');
  }

  /// Flattens [segments] with the chat-position entries inserted.
  ///
  /// Slots are segment boundaries `0..L` (L = after the last segment):
  /// - TOP_OF_CHAT → slot 0;
  /// - BOTTOM_OF_CHAT → before the last segment (slot `L-1`, or 0);
  /// - AT_DEPTH(0) → slot L (after everything; assistant role forced to user
  ///   so it is never a trailing assistant prefill);
  /// - AT_DEPTH(n≥1) → before the n-th user segment counted from the end,
  ///   clamped to slot 0 when the history has fewer user turns.
  ///
  /// Within one slot: top, then at-depth (deeper first), then bottom.
  ///
  /// [mergeAdjacentUser] folds each injected user message into the plain user
  /// turn right after it (or, failing that, right before it) when that turn is
  /// a user-role segment — never into a tool segment, never into an assistant.
  static List<LlmMessage> injectMessages(
    List<LlmMessageSegment> segments,
    List<WorldBookEntry> entries, {
    bool mergeAdjacentUser = false,
  }) {
    final chat = [
      for (final e in entries)
        if (_isChatPosition(e.position) && e.content.trim().isNotEmpty) e,
    ];
    if (chat.isEmpty) {
      return [for (final segment in segments) ...segment.messages];
    }
    final length = segments.length;
    final slots = List<List<LlmMessage>>.generate(
      length + 1,
      (_) => <LlmMessage>[],
    );
    final userStarts = [
      for (var i = 0; i < length; i++)
        if (segments[i].role == MessageRole.user) i,
    ];

    slots[0].addAll(_merge(_at(chat, WorldBookInjectionPosition.topOfChat)));

    final byDepth = <int, List<WorldBookEntry>>{};
    for (final e in _at(chat, WorldBookInjectionPosition.atDepth)) {
      byDepth
          .putIfAbsent(
            e.injectDepth.clamp(0, WorldBookEntry.kMaxDepth),
            () => <WorldBookEntry>[],
          )
          .add(e);
    }
    for (final depth in byDepth.keys.toList()..sort((a, b) => b - a)) {
      final slot = depth == 0
          ? length
          : depth <= userStarts.length
          ? userStarts[userStarts.length - depth]
          : 0;
      slots[slot].addAll(
        _merge(byDepth[depth]!, forceUser: depth == 0),
      );
    }

    slots[length > 0 ? length - 1 : 0].addAll(
      _merge(_at(chat, WorldBookInjectionPosition.bottomOfChat)),
    );

    if (!mergeAdjacentUser) {
      return [
        for (var i = 0; i <= length; i++) ...[
          ...slots[i],
          if (i < length) ...segments[i].messages,
        ],
      ];
    }
    return _fold(segments, slots);
  }

  /// Folds a slot's injected user messages (joined in order) into the
  /// neighbouring plain user segment: prepended to the next segment's first
  /// message, else — only when the slot holds no assistant injection, so the
  /// relative order is kept — appended to the previous segment's last message,
  /// else kept standalone. Tool-result segments are never touched.
  static List<LlmMessage> _fold(
    List<LlmMessageSegment> segments,
    List<List<LlmMessage>> slots,
  ) {
    final length = segments.length;
    final bodies = [for (final s in segments) List<LlmMessage>.of(s.messages)];
    bool isPlainUser(int i) =>
        i >= 0 &&
        i < length &&
        segments[i].role == MessageRole.user &&
        bodies[i].isNotEmpty &&
        bodies[i].every((m) => m.toolCallId == null);
    final standalone = List<List<LlmMessage>>.generate(
      length + 1,
      (_) => <LlmMessage>[],
    );
    for (var slot = 0; slot <= length; slot++) {
      final users = [
        for (final m in slots[slot])
          if (m.role == MessageRole.user) m.content,
      ];
      final others = [
        for (final m in slots[slot])
          if (m.role != MessageRole.user) m,
      ];
      final joined = users.join('\n\n');
      if (users.isEmpty) {
        standalone[slot].addAll(others);
      } else if (isPlainUser(slot)) {
        standalone[slot].addAll(others);
        final first = bodies[slot].first;
        bodies[slot][0] = first.copyWith(
          content: '$joined\n\n${first.content}',
        );
      } else if (others.isEmpty && isPlainUser(slot - 1)) {
        final prev = bodies[slot - 1];
        prev[prev.length - 1] = prev.last.copyWith(
          content: '${prev.last.content}\n\n$joined',
        );
      } else {
        standalone[slot].addAll(slots[slot]);
      }
    }
    return [
      for (var i = 0; i <= length; i++) ...[
        ...standalone[i],
        if (i < length) ...bodies[i],
      ],
    ];
  }

  static bool _isChatPosition(WorldBookInjectionPosition position) =>
      position == WorldBookInjectionPosition.topOfChat ||
      position == WorldBookInjectionPosition.bottomOfChat ||
      position == WorldBookInjectionPosition.atDepth;

  static List<WorldBookEntry> _at(
    List<WorldBookEntry> entries,
    WorldBookInjectionPosition position,
  ) => [
    for (final e in entries)
      if (e.position == position) e,
  ];

  static String _join(
    Iterable<WorldBookEntry> entries, [
    WorldBookInjectionPosition? position,
  ]) => entries
      .where((e) => position == null || e.position == position)
      .map((e) => e.content.trim())
      .where((c) => c.isNotEmpty)
      .join('\n');

  /// One message per role, roles in order of first appearance (kelivo).
  static List<LlmMessage> _merge(
    List<WorldBookEntry> entries, {
    bool forceUser = false,
  }) {
    final byRole = <WorldBookInjectionRole, List<WorldBookEntry>>{};
    for (final e in entries) {
      final role = forceUser ? WorldBookInjectionRole.user : e.role;
      byRole.putIfAbsent(role, () => <WorldBookEntry>[]).add(e);
    }
    return [
      for (final MapEntry(key: role, value: group) in byRole.entries)
        if (_join(group) case final text when text.isNotEmpty)
          role == WorldBookInjectionRole.assistant
              ? LlmMessage(role: MessageRole.assistant, content: text)
              : LlmMessage(
                  role: MessageRole.user,
                  content: '<system>\n$text\n</system>',
                ),
    ];
  }
}
