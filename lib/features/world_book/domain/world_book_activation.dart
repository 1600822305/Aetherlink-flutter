import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

/// 计时器状态在持久层（P3 起写入 user 消息 metadata）里的键。
const String kWorldBookActivationMetadataKey = 'worldBook.activation';

/// [WorldBookActivation.evaluate] 的结果：按 priority 排好序的触发条目，以及
/// 下一轮要回传的计时器状态（可直接 JSON 编码）。
typedef WorldBookActivationResult = ({
  List<WorldBookEntry> entries,
  Map<String, dynamic> state,
});

/// 关键词 / 正则激活与 sticky / cooldown / delay 计时器。逐行移植自 kelivo
/// `WorldBookActivation`（行为保持一致，测试同源）。
///
/// 计时器以真实对话消息计数，不含合成注入与工具调用；对同一段历史重复评估是
/// 幂等的。内容哈希让克隆了消息 id 的分支能继承计时效果，回退或改写已评估的
/// 前缀则使效果失效。
abstract final class WorldBookActivation {
  static WorldBookActivationResult evaluate({
    required List<WorldBook> books,
    required List<Map<String, dynamic>> scanMessages,
    required List<Map<String, dynamic>> history,
    Map<String, dynamic> previous = const <String, dynamic>{},
  }) {
    String fingerprint(Object value) =>
        sha256.convert(utf8.encode(jsonEncode(value))).toString();
    final count = history.length;
    final rawCount = previous['messageCount'];
    final previousCount = rawCount is int ? rawCount : 0;
    final continuesHistory =
        previous['historyHash'] != null &&
        previousCount >= 0 &&
        previousCount <= count &&
        previous['historyHash'] ==
            fingerprint(history.take(previousCount).toList());
    final rawEffects = previous['effects'];
    final oldEffects = continuesHistory && rawEffects is Map<dynamic, dynamic>
        ? rawEffects
        : const <dynamic, dynamic>{};
    final effects = <String, dynamic>{};
    final triggered = <({WorldBookEntry entry, int seq})>[];
    final contextCache = <int, String>{};
    var seq = 0;

    String contextFor(int depth) => contextCache.putIfAbsent(depth, () {
      final parts = scanMessages.reversed
          .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
          .map((m) => (m['content'] ?? '').toString().trim())
          .where((text) => text.isNotEmpty)
          .take(depth)
          .toList()
          .reversed;
      return parts.join('\n');
    });

    for (final book in books) {
      if (!book.enabled) continue;
      for (final entry in book.entries) {
        final order = seq++;
        if (!entry.enabled || entry.content.trim().isEmpty) continue;
        final key = jsonEncode([book.id, entry.id]);
        final signature = entry.sticky > 0 || entry.cooldown > 0
            ? fingerprint(entry.toJson())
            : '';
        final raw = oldEffects[key];
        final effect = raw is Map<dynamic, dynamic> && raw['signature'] == signature
            ? raw
            : null;
        final activatedAt = effect?['activatedAt'] as int?;
        var active = false;
        if (activatedAt != null && activatedAt <= count) {
          final elapsed = count - activatedAt;
          if (elapsed <= entry.sticky) {
            active = true;
            effects[key] = effect;
          } else if (elapsed <= entry.sticky + entry.cooldown) {
            effects[key] = effect;
            continue;
          }
        }
        if (!active) {
          if (count < entry.delay) continue;
          active = matches(
            entry,
            contextFor(entry.scanDepth.clamp(1, WorldBookEntry.kMaxDepth)),
          );
          if (active && (entry.sticky > 0 || entry.cooldown > 0)) {
            effects[key] = <String, dynamic>{
              'signature': signature,
              'activatedAt': count,
            };
          }
        }
        if (active) triggered.add((entry: entry, seq: order));
      }
    }
    triggered.sort((a, b) {
      final priority = b.entry.priority.compareTo(a.entry.priority);
      return priority != 0 ? priority : a.seq.compareTo(b.seq);
    });
    return (
      entries: triggered.map((item) => item.entry).toList(),
      state: <String, dynamic>{
        'messageCount': count,
        'historyHash': effects.isEmpty ? '' : fingerprint(history),
        'effects': effects,
      },
    );
  }

  static bool matches(WorldBookEntry entry, String context) {
    if (!entry.enabled) return false;
    if (entry.constantActive) return true;
    for (final raw in entry.keywords) {
      final keyword = raw.trim();
      if (keyword.isEmpty) continue;
      if (entry.useRegex) {
        try {
          if (RegExp(
            keyword,
            caseSensitive: entry.caseSensitive,
          ).hasMatch(context)) {
            return true;
          }
        } on FormatException {
          // 一个非法表达式不能连带屏蔽同条目的其它关键词。
        }
      } else if (entry.caseSensitive
          ? context.contains(keyword)
          : context.toLowerCase().contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}
