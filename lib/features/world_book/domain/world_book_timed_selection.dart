import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_macros.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_scan_context.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_settings.dart';

/// [selectTimedWorldBookEntries]'s result: the activated entries in injection
/// order, the state to persist on this turn's user message, and whether the
/// token budget stopped activation（ST `world_info_overflow_alert` 用）。
typedef WorldBookTimedResult = ({
  List<WorldBookEntry> entries,
  WorldBookActivationState state,
  bool budgetOverflowed,
});

/// ST `scan_state`.
enum _ScanState { none, initial, recursion, minActivations }

/// 一个参与扫描的条目及其书序 / 条目序、计时信息。
class _Candidate {
  _Candidate({
    required this.entry,
    required this.probe,
    required this.book,
    required this.seq,
    required this.key,
    required this.timed,
    required this.signature,
    required this.sticky,
    required this.cooldown,
    required this.content,
    required this.activate,
    required this.dontActivate,
  });

  final WorldBookEntry entry;

  /// 关键词已做宏替换、用于匹配的条目。
  final WorldBookEntry probe;
  final int book;
  final int seq;
  final String key;
  final bool timed;
  final String signature;

  /// 本轮处于持续（由上一轮带过来的计时效果）。
  final bool sticky;

  /// 本轮处于冷却（且不在持续里）。
  final bool cooldown;

  /// 去掉装饰器行、做过宏替换的内容（注入、递归、预算都用它）。
  final String content;

  /// `@@activate`：像常驻一样直接激活。
  final bool activate;

  /// `@@dont_activate`：无论如何都不激活（优先级低于 `@@activate`）。
  final bool dontActivate;
}

/// 一轮的激活，主循环逐段对照 SillyTavern `checkWorldInfo`：
///
/// 1. **候选**：每次扫描遍历所有条目，跳过已激活 / 概率已失败 / 关闭 / 延迟中 /
///    冷却中（且不在持续里）的；`delayUntilRecursion` 的条目只在递归扫描、且
///    到了它的层级时才参与；递归扫描时跳过「不可被递归激活」的。常驻与持续中的
///    直接成为候选，其余按 [WorldBookActivation.matches] 匹配。
/// 2. **包含组**（[_filterByInclusionGroups]）：组里有持续中的条目时它们胜出；
///    开启评分时只留命中数最高的；该组在之前的扫描里已激活过就整组移除；
///    有「组内优先」的取 order 最大的；否则按权重随机选一个。
/// 3. **概率**：持续中的不再判定；失败的条目本次评估内不再参与。
/// 4. **预算**：累计 token 达到预算就停止激活（「不计入预算」的照常加入），并
///    停止后续扫描。
/// 5. **继续扫描**：开启递归、未超预算、且有可递归的新条目（未设「阻止后续递归」）
///    → 把它们的内容追加到扫描文本再扫一次；`maxRecursionSteps` 限制总扫描次数；
///    激活数不到「最少激活数」→ 全局扫描深度 +1 再扫（不带递归文本），直到够数或
///    超过深度上限 / 聊天长度；还有没放开的 `delayUntilRecursion` 层级 → 进入下一层。
///
/// 扫描文本：最近的消息在前，`\x01` 开头、`\n\x01` 分隔（[scanTexts] 由调用方
/// 加好 `名字: ` 前缀）；递归扫描时再追加已激活条目的内容。
///
/// [turn] 是本次评估时的**消息序号**（ST `chat.length`：当前路径上的用户与助手
/// 消息数，含刚发出的这条用户消息，见 [resolveWorldBookClock]）；[previous] 是
/// 最近祖先的计时状态。计时器与 ST `WorldInfoTimedEffects` 一致，都按消息条数：
/// - 延迟：`turn < delay` 时不能激活；
/// - 持续：第 C 条激活后，`turn < C + sticky` 期间保持激活（不再匹配、不重判概率）；
/// - 冷却：没有持续的从 C 起算，`turn < C + cooldown` 期间不能激活；有持续的
///   在持续到期时（第 E 条）重新起算，`turn < E + cooldown` 期间不能激活。
///
/// 生成类型（[trigger]，ST `triggers`）与角色筛选（[character]，ST
/// `characterFilter`）最先判断，不通过的条目不参与；勾选了「额外匹配源」的
/// 条目把 [sources] 里对应的文本追加到扫描文本（在聊天记录之后、递归文本之前）。
///
/// 装饰器（[parseWorldBookDecorators]）：`@@activate` 直接激活；
/// `@@dont_activate` 不激活，连持续中的也不激活（ST 在判定持续之前检查装饰器）。
///
/// 预算：[contextTokens] 为上下文长度时预算 = `budgetPercent%`，再受
/// `budgetCap` 约束；不知道上下文长度时只用 `budgetCap`（0 = 不限）。
/// [countTokens] 缺省按字符数粗估；[random] 供概率与组内随机使用（测试可固定）。
///
/// 结果按注入顺序：`order` 小的在前；同 `order` 时书序优先，书内 uid 大的在前。
WorldBookTimedResult selectTimedWorldBookEntries({
  required List<WorldBook> books,
  required List<String> scanTexts,
  required int turn,
  WorldBookActivationState previous = WorldBookActivationState.empty,
  WorldBookSettings settings = WorldBookSettings.defaults,
  WorldBookMacroContext? macros,
  int? contextTokens,
  int Function(String text)? countTokens,
  Random? random,
  String trigger = WorldBookTrigger.normal,
  WorldBookCharacter? character,
  WorldBookScanSources sources = WorldBookScanSources.none,
}) {
  final rnd = random ?? Random();
  final tokens = countTokens ?? _roughTokens;
  final texts = [
    for (final text in scanTexts)
      if (text.trim().isNotEmpty) text.trim(),
  ];
  String sub(String s) =>
      macros == null ? s : substituteWorldBookMacros(s, macros);

  // ── 候选准备：计时效果、宏替换后的关键词 ────────────────────────────
  final effects = <String, WorldBookEffect>{};
  final candidates = <_Candidate>[];
  for (var b = 0; b < books.length; b++) {
    final book = books[b];
    if (!book.enabled) continue;
    for (var i = 0; i < book.entries.length; i++) {
      final entry = book.entries[i];
      if (!entry.enabled || entry.content.trim().isEmpty) continue;
      if (!worldBookTriggerAllows(entry, trigger)) continue;
      if (!worldBookCharacterAllows(entry, character)) continue;
      final sticky = entry.sticky ?? 0;
      final cooldown = entry.cooldown ?? 0;
      final delay = entry.delay ?? 0;
      // 延迟最先判断（ST：处于延迟的条目连持续也不看）。
      if (delay > 0 && turn < delay) continue;
      final timed = sticky > 0 || cooldown > 0;
      final key = jsonEncode([book.id, entry.id]);
      final signature = timed ? worldBookTimerSignature(entry) : '';
      final carried = previous.effects[key];
      final effect =
          timed && carried != null && carried.signature == signature
          ? carried
          : null;
      var isSticky = false;
      var isCooldown = false;
      if (effect != null && effect.activatedAt < turn) {
        if (sticky > 0 && turn < effect.activatedAt + sticky) {
          isSticky = true;
          effects[key] = effect;
        } else if (cooldown > 0) {
          // 持续到期的那一刻起算冷却（ST onEnded.sticky）；没有持续时从激活算。
          final from = sticky > 0
              ? (effect.cooldownFrom ?? turn)
              : effect.activatedAt;
          if (turn < from + cooldown) {
            isCooldown = true;
            effects[key] = sticky > 0 ? effect.withCooldownFrom(from) : effect;
          }
        }
      }
      if (isCooldown) continue;
      final parsed = parseWorldBookDecorators(entry.content);
      candidates.add(
        _Candidate(
          entry: entry,
          probe: macros == null
              ? entry
              : entry.copyWith(
                  keywords: [for (final k in entry.keywords) sub(k)],
                  secondaryKeywords: [
                    for (final k in entry.secondaryKeywords) sub(k),
                  ],
                ),
          book: b,
          seq: i,
          key: key,
          timed: timed,
          signature: signature,
          sticky: isSticky,
          cooldown: isCooldown,
          content: sub(parsed.content),
          activate: parsed.decorators.any((d) => d.startsWith('@@activate')),
          dontActivate: parsed.decorators.any(
            (d) => d.startsWith('@@dont_activate'),
          ),
        ),
      );
    }
  }
  // ST 的 getSortedEntries：order 大的在前（同 order 保持书序 / 条目序）。
  int uid(WorldBookEntry e) => int.tryParse(e.id) ?? 0;
  final sorted = [...candidates]
    ..sort((a, b) {
      final order = b.entry.order.compareTo(a.entry.order);
      if (order != 0) return order;
      final book = a.book.compareTo(b.book);
      return book != 0 ? book : a.seq.compareTo(b.seq);
    });
  final rank = {for (var i = 0; i < sorted.length; i++) sorted[i]: i};

  // ── 预算 ──────────────────────────────────────────────────────────
  var budget = 0; // 0 = 不限
  if (contextTokens != null && contextTokens > 0) {
    budget = (settings.budgetPercent * contextTokens / 100).round();
    if (budget < 1) budget = 1;
  }
  if (settings.budgetCap > 0 && (budget == 0 || budget > settings.budgetCap)) {
    budget = settings.budgetCap;
  }

  // ── 递归延迟层级 ──────────────────────────────────────────────────
  final delayLevels =
      {
          for (final c in candidates)
            if (c.entry.delayUntilRecursion > 0) c.entry.delayUntilRecursion,
        }.toList()
        ..sort();
  var currentDelayLevel = delayLevels.isEmpty ? 0 : delayLevels.removeAt(0);

  // ── 扫描状态 ──────────────────────────────────────────────────────
  final activated = <_Candidate>[];
  final activatedSet = <_Candidate>{};
  final failedProbability = <_Candidate>{};
  final recurseTexts = <String>[];
  var allActivatedText = '';
  var depthSkew = 0;
  var overflowed = false;
  var state = _ScanState.initial;
  var count = 0;

  String contextFor(_Candidate c, _ScanState s) {
    final depth = (c.entry.scanDepth ?? (settings.scanDepth + depthSkew))
        .clamp(0, WorldBookEntry.kMaxScanDepth);
    if (depth <= 0) return '';
    final buf = StringBuffer('\x01')
      ..write(texts.reversed.take(depth).join('\n\x01'));
    for (final extra in sources.forEntry(c.entry)) {
      buf
        ..write('\n\x01')
        ..write(extra);
    }
    if (recurseTexts.isNotEmpty && s != _ScanState.minActivations) {
      buf
        ..write('\n\x01')
        ..write(recurseTexts.join('\n\x01'));
    }
    return buf.toString();
  }

  while (state != _ScanState.none) {
    if (settings.maxRecursionSteps > 0 && settings.maxRecursionSteps <= count) {
      break;
    }
    count++;

    // 1. 候选
    final now = <_Candidate>[];
    for (final c in sorted) {
      if (activatedSet.contains(c) || failedProbability.contains(c)) continue;
      final e = c.entry;
      if (e.delayUntilRecursion > 0 && !c.sticky) {
        if (state != _ScanState.recursion) continue;
        if (e.delayUntilRecursion > currentDelayLevel) continue;
      }
      if (state == _ScanState.recursion &&
          settings.recursive &&
          e.excludeRecursion &&
          !c.sticky) {
        continue;
      }
      if (c.activate) {
        now.add(c);
        continue;
      }
      if (c.dontActivate) continue;
      if (e.constant || c.sticky) {
        now.add(c);
        continue;
      }
      if (WorldBookActivation.matches(
        c.probe,
        contextFor(c, state),
        settings: settings,
      )) {
        now.add(c);
      }
    }

    // 持续中的排在最前，其余保持 order 降序。
    now.sort((a, b) {
      if (a.sticky != b.sticky) return a.sticky ? -1 : 1;
      return rank[a]!.compareTo(rank[b]!);
    });

    // 2. 包含组
    _filterByInclusionGroups(
      now,
      activated,
      settings: settings,
      random: rnd,
      scoreOf: (c) => WorldBookActivation.score(
        c.probe,
        contextFor(c, state),
        settings: settings,
      ),
    );

    // 3. 概率 + 4. 预算
    final baseTokens = allActivatedText.isEmpty ? 0 : tokens(allActivatedText);
    final newContent = StringBuffer();
    final accepted = <_Candidate>[];
    for (final c in now) {
      final e = c.entry;
      final passes =
          !e.useProbability ||
          c.sticky ||
          rnd.nextDouble() * 100 <= e.probability;
      if (!passes) {
        failedProbability.add(c);
        continue;
      }
      if (overflowed && !e.ignoreBudget) continue;
      newContent
        ..write(c.content)
        ..write('\n');
      if (budget > 0 &&
          !e.ignoreBudget &&
          baseTokens + tokens(newContent.toString()) >= budget) {
        overflowed = true;
        continue;
      }
      accepted.add(c);
      activated.add(c);
      activatedSet.add(c);
      if (c.timed && !c.sticky) {
        effects[c.key] = WorldBookEffect(
          activatedAt: turn,
          signature: c.signature,
        );
      }
    }

    // 5. 下一次扫描
    final forRecursion = [
      for (final c in accepted)
        if (!c.entry.preventRecursion) c,
    ];
    var next = _ScanState.none;
    if (settings.recursive && !overflowed && forRecursion.isNotEmpty) {
      next = _ScanState.recursion;
    }
    if (settings.recursive &&
        !overflowed &&
        state == _ScanState.minActivations &&
        recurseTexts.isNotEmpty) {
      next = _ScanState.recursion;
    }
    if (next == _ScanState.none &&
        !overflowed &&
        settings.minActivations > 0 &&
        activated.length < settings.minActivations) {
      final depth = settings.scanDepth + depthSkew;
      final overMax =
          (settings.minActivationsDepthMax > 0 &&
              depth > settings.minActivationsDepthMax) ||
          depth > texts.length;
      if (!overMax) {
        next = _ScanState.minActivations;
        depthSkew++;
      }
    }
    if (next == _ScanState.none && settings.recursive && delayLevels.isNotEmpty) {
      next = _ScanState.recursion;
      currentDelayLevel = delayLevels.removeAt(0);
    }
    if (next != _ScanState.none && forRecursion.isNotEmpty) {
      final text = [for (final c in forRecursion) c.content].join('\n');
      recurseTexts.add(text);
      allActivatedText = allActivatedText.isEmpty
          ? text
          : '$text\n$allActivatedText';
    }
    state = next;
  }

  activated.sort((a, b) {
    final order = a.entry.order.compareTo(b.entry.order);
    if (order != 0) return order;
    final book = a.book.compareTo(b.book);
    if (book != 0) return book;
    final byUid = uid(b.entry).compareTo(uid(a.entry));
    return byUid != 0 ? byUid : b.seq.compareTo(a.seq);
  });
  return (
    entries: [
      for (final c in activated)
        c.content == c.entry.content ? c.entry : c.entry.copyWith(content: c.content),
    ],
    state: WorldBookActivationState(turn: turn, effects: effects),
    budgetOverflowed: overflowed,
  );
}

/// ST `filterByInclusionGroups`（含 `filterGroupsByScoring`）：就地从 [now]
/// 里移除落选的条目。[activated] 是之前扫描已激活的条目。
void _filterByInclusionGroups(
  List<_Candidate> now,
  List<_Candidate> activated, {
  required WorldBookSettings settings,
  required Random random,
  required int Function(_Candidate) scoreOf,
}) {
  final grouped = <String, List<_Candidate>>{};
  for (final c in now) {
    for (final g in c.entry.groups) {
      (grouped[g] ??= <_Candidate>[]).add(c);
    }
  }
  if (grouped.isEmpty) return;
  void remove(_Candidate c) => now.remove(c);
  void removeAllBut(List<_Candidate> group, _Candidate keep) {
    for (final c in group) {
      if (!identical(c, keep)) remove(c);
    }
  }

  // 组里有持续中的条目：它们胜出，其余移除。
  final hasSticky = <String>{};
  for (final MapEntry(key: name, value: group) in grouped.entries) {
    final sticky = group.where((c) => c.sticky).toList();
    if (sticky.isEmpty) continue;
    hasSticky.add(name);
    for (final c in group) {
      if (!c.sticky) remove(c);
    }
  }

  // 评分：只保留命中数最高的（只对开启了评分的条目生效）。
  for (final MapEntry(key: name, value: group) in grouped.entries) {
    if (hasSticky.contains(name)) continue;
    final anyScored =
        settings.useGroupScoring || group.any((c) => c.entry.useGroupScoring == true);
    if (!anyScored) continue;
    final scores = [for (final c in group) scoreOf(c)];
    final maxScore = scores.fold<int>(0, max);
    for (var i = group.length - 1; i >= 0; i--) {
      final scored = group[i].entry.useGroupScoring ?? settings.useGroupScoring;
      if (scored && scores[i] < maxScore) {
        remove(group[i]);
        group.removeAt(i);
      }
    }
  }

  for (final MapEntry(key: name, value: group) in grouped.entries) {
    if (hasSticky.contains(name)) continue;
    // 这个组在之前的扫描里已经激活过：整组移除。
    if (activated.any((c) => c.entry.groups.contains(name))) {
      group.forEach(remove);
      continue;
    }
    final alive = [
      for (final c in group)
        if (now.contains(c)) c,
    ];
    if (alive.length <= 1) continue;
    final prios = alive.where((c) => c.entry.groupOverride).toList()
      ..sort((a, b) => b.entry.order.compareTo(a.entry.order));
    if (prios.isNotEmpty) {
      removeAllBut(alive, prios.first);
      continue;
    }
    final total = alive.fold<int>(0, (s, c) => s + c.entry.groupWeight);
    final roll = random.nextDouble() * total;
    var acc = 0;
    _Candidate? winner;
    for (final c in alive) {
      acc += c.entry.groupWeight;
      if (roll <= acc) {
        winner = c;
        break;
      }
    }
    if (winner != null) removeAllBut(alive, winner);
  }
}

/// 粗略 token 估算（约 4 个 ASCII 字符或 1 个汉字算 1 个 token）。
int _roughTokens(String text) {
  var ascii = 0;
  var other = 0;
  for (final r in text.runes) {
    r < 128 ? ascii++ : other++;
  }
  return (ascii / 4).ceil() + other;
}

/// 决定计时效果的设置指纹；改了条目任何字段，正在进行的计时都会失效
/// （ST 同样按整条目的哈希认条目）。
String worldBookTimerSignature(WorldBookEntry entry) =>
    sha256.convert(utf8.encode(jsonEncode(entry.toJson()))).toString();
