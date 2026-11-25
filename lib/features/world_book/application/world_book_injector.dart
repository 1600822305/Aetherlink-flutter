import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message_segment.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

/// Splices triggered 世界书 entries into a request.
///
/// - ST 位置 0 / 1（系统提示词之前 / 之后）：拼进 system 文本；
/// - ST 位置 4（@深度）：与 ST chat completion（`populationInjectionPrompts`）
///   一致——深度按**消息**计（一个段 = 一条消息视图），深度 n 插在最后 n 条之前；
///   同一深度按角色合成至多三条消息，顺序为 assistant、user、system；不同深度里
///   深的在前。只插在**消息段之间**，assistant 的 `toolCalls` 与工具结果、提示词
///   注入的 `<tool_use>` 回合永远不会被拆开；
/// - ST 位置 7（Outlet）：不自动注入，按名字收集后替换系统提示词里的
///   `{{outlet::名字}}`（ST 同名宏；名字不区分大小写，没有对应条目时替换为空）；
/// - 作者注释、示例消息两类位置本应用暂无对应，**不注入**。
///
/// 供应商兼容（只在这一层做，激活结果与 ST 相同）：
/// - [nativeSystem] 为 false（Anthropic / Gemini 等不接受聊天中间 system 消息
///   的协议）时，system 角色改为 user 消息、内容包在 `<system>…</system>` 里；
/// - 深度 0 的 assistant 按 system 处理，避免末尾出现助手预填；
/// - [mergeAdjacentUser]（生产默认 [kWorldBookMergeAdjacentUser]）把注入的 user
///   消息并进相邻的用户消息（部分旧接口拒绝连续两条 user）。
///
/// [entries] 必须已按注入顺序排好（[selectTimedWorldBookEntries]：order 小的在
/// 前），每条合成消息内部保持这个顺序。没有触发任何条目时原样返回。
const bool kWorldBookMergeAdjacentUser = true;

abstract final class WorldBookInjector {
  /// [system] with the before / after-system entries joined in. A null or
  /// empty [system] yields just the world book text.
  ///
  /// `{{outlet::名字}}` 在拼接前替换（只替换 [system] 里的，条目内容里的不展开）。
  static String? injectSystem(String? system, List<WorldBookEntry> entries) {
    final before = _join(entries, WorldBookInjectionPosition.beforeSystemPrompt);
    final after = _join(entries, WorldBookInjectionPosition.afterSystemPrompt);
    final withOutlets = system == null ? null : fillOutlets(system, entries);
    if (before.isEmpty && after.isEmpty) return withOutlets;
    final base = withOutlets ?? '';
    final parts = [
      if (before.isNotEmpty) before,
      if (base.isNotEmpty) base,
      if (after.isNotEmpty) after,
    ];
    return parts.join('\n');
  }

  /// ST `{{outlet::名字}}` 宏：替换成名字相同（不区分大小写、去掉首尾空白）的
  /// Outlet 条目内容，多条按注入顺序用换行拼接；没有对应条目时替换为空。
  static String fillOutlets(String text, List<WorldBookEntry> entries) {
    if (!text.contains('{{')) return text;
    final byName = <String, List<WorldBookEntry>>{};
    for (final e in entries) {
      if (e.position != WorldBookInjectionPosition.outlet) continue;
      final name = e.outletName.trim().toLowerCase();
      if (name.isEmpty) continue;
      (byName[name] ??= <WorldBookEntry>[]).add(e);
    }
    return text.replaceAllMapped(
      RegExp(r'\{\{outlet::([^}]*)\}\}', caseSensitive: false),
      (m) => _join(byName[m.group(1)!.trim().toLowerCase()] ?? const []),
    );
  }

  /// Flattens [segments] with the @深度 entries inserted.
  ///
  /// Slots are segment boundaries `0..L` (L = after the last segment): depth n
  /// goes to slot `L - n`, clamped to 0 when the history is shorter.
  static List<LlmMessage> injectMessages(
    List<LlmMessageSegment> segments,
    List<WorldBookEntry> entries, {
    bool mergeAdjacentUser = false,
    bool nativeSystem = false,
  }) {
    final chat = [
      for (final e in entries)
        if (e.position == WorldBookInjectionPosition.atDepth &&
            e.content.trim().isNotEmpty)
          e,
    ];
    if (chat.isEmpty) {
      return [for (final segment in segments) ...segment.messages];
    }
    final length = segments.length;
    final slots = List<List<LlmMessage>>.generate(
      length + 1,
      (_) => <LlmMessage>[],
    );

    final byDepth = <int, List<WorldBookEntry>>{};
    for (final e in chat) {
      byDepth
          .putIfAbsent(
            e.depth.clamp(0, WorldBookEntry.kMaxNumber),
            () => <WorldBookEntry>[],
          )
          .add(e);
    }
    for (final depth in byDepth.keys.toList()..sort((a, b) => b - a)) {
      final slot = depth >= length ? 0 : length - depth;
      slots[slot].addAll(
        _depthMessages(
          byDepth[depth]!,
          trailing: depth == 0,
          nativeSystem: nativeSystem,
        ),
      );
    }

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

  static String _join(
    Iterable<WorldBookEntry> entries, [
    WorldBookInjectionPosition? position,
  ]) => entries
      .where((e) => position == null || e.position == position)
      .map((e) => e.content.trim())
      .where((c) => c.isNotEmpty)
      .join('\n');

  /// One depth's messages, ST order: assistant, user, system. [trailing]
  /// (depth 0) turns assistant into system so the request never ends on an
  /// assistant prefill.
  static List<LlmMessage> _depthMessages(
    List<WorldBookEntry> entries, {
    required bool trailing,
    required bool nativeSystem,
  }) {
    final assistant = trailing
        ? ''
        : _join([
            for (final e in entries)
              if (e.role == WorldBookInjectionRole.assistant) e,
          ]);
    final user = _join([
      for (final e in entries)
        if (e.role == WorldBookInjectionRole.user) e,
    ]);
    final system = _join([
      for (final e in entries)
        if (e.role == WorldBookInjectionRole.system ||
            (trailing && e.role == WorldBookInjectionRole.assistant))
          e,
    ]);
    return [
      if (assistant.isNotEmpty)
        LlmMessage(role: MessageRole.assistant, content: assistant),
      if (user.isNotEmpty) LlmMessage(role: MessageRole.user, content: user),
      if (system.isNotEmpty)
        nativeSystem
            ? LlmMessage(role: MessageRole.system, content: system)
            : LlmMessage(
                role: MessageRole.user,
                content: '<system>\n$system\n</system>',
              ),
    ];
  }
}
