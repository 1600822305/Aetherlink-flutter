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
///
/// [reasons] 与 [entries] 一一对应，是给用户看的激活原因（见
/// [_Candidate.reason]）。
typedef WorldBookTimedResult = ({
  List<WorldBookEntry> entries,
  List<String> reasons,
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
    required this.bookName,
  });

  final String bookName;

  /// 激活原因，激活时写入：常驻 / 持续中 / @@activate / 命中的关键词，递归和
  /// 「最少激活数」扩大深度时再加说明。
  String reason = '';

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
/// [outletNames]：提示词里引用到的 Outlet 名字（小写，见
/// [worldBookOutletNamesIn]）；给出时没被引用的 Outlet 条目不参与。
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
  Set<String>? outletNames,
}) {
  final rnd = random ?? Random();
  final tokens = countTokens ?? worldBookRoughTokens;
  final texts = [
    for (final text in scanTexts)
      if (text.trim().isNotEmpty) text.trim(),
  ];
  String sub(String s) =>
      macros == null ? s : substituteWorldBookMacros(s, macros);

  // ── 候选准备：计时效果、宏替换后的关键词 ────────────────────────────
  // 先继承上一轮的全部计时状态，绑定的书里的条目在下面逐条重新计算；这次没
  // 绑定的书（比如话题临时换了书）的状态原样保留，换回来时接着算。所在的书
  // 还在、条目已经删掉的状态直接丢弃。
  final effects = <String, WorldBookEffect>{...previous.effects};
  final liveBooks = {for (final book in books) book.id: book};
  effects.removeWhere((key, _) {
    try {
      final parts = jsonDecode(key);
      if (parts is! List<dynamic> || parts.length != 2) return true;
      final book = liveBooks['${parts[0]}'];
      return book != null && !book.entries.any((e) => e.id == '${parts[1]}');
    } on Object {
      return true;
    }
  });
  final candidates = <_Candidate>[];
  for (var b = 0; b < books.length; b++) {
    final book = books[b];
    if (!book.enabled) continue;
    for (var i = 0; i < book.entries.length; i++) {
      final entry = book.entries[i];
      final sticky = entry.sticky ?? 0;
      final cooldown = entry.cooldown ?? 0;
      final delay = entry.delay ?? 0;
      // 计时状态对绑定的书里**所有**条目都推进（ST checkTimedEffects 遍历全部
      // 条目，含关闭的），之后才判断这一轮能不能参与；否则被跳过的条目会错过
      // 「持续到期 → 开始冷却」的时刻。
      final timed = sticky > 0 || cooldown > 0;
      final key = jsonEncode([book.id, entry.id]);
      final signature = timed ? worldBookTimerSignature(entry) : '';
      final carried = effects.remove(key);
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
      if (!entry.enabled || entry.content.trim().isEmpty) continue;
      // 本应用没有对应位置（作者注释 / 示例消息）的条目不会被注入，也就不该
      // 占预算、抢包含组名额、出现在「本轮注入」里。
      if (!entry.position.isImplemented) continue;
      // Outlet 条目只有在提示词里被 `{{outlet::名字}}` 引用时才会进请求；没被
      // 引用的同样不参与（不占预算、不计入「本轮注入」）。null = 不检查。
      if (outletNames != null &&
          entry.position == WorldBookInjectionPosition.outlet &&
          !outletNames.contains(entry.outletName.trim().toLowerCase())) {
        continue;
      }
      if (!worldBookTriggerAllows(entry, trigger)) continue;
      if (!worldBookCharacterAllows(entry, character)) continue;
      // 延迟优先于持续（ST：处于延迟的条目连持续也不看）。
      if (delay > 0 && turn < delay) continue;
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
          bookName: book.name,
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
        c.reason = '@@activate';
        now.add(c);
        continue;
      }
      if (c.dontActivate) continue;
      if (e.constant) {
        c.reason = '常驻';
        now.add(c);
        continue;
      }
      if (c.sticky) {
        final at = previous.effects[c.key]?.activatedAt;
        c.reason = at == null ? '持续中' : '持续中（第 $at 条消息时激活）';
        now.add(c);
        continue;
      }
      final context = contextFor(c, state);
      if (WorldBookActivation.matches(c.probe, context, settings: settings)) {
        c.reason = _keywordReason(c.probe, context, settings, state);
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
    reasons: [
      for (final c in activated)
        c.bookName.trim().isEmpty ? c.reason : '${c.reason} · 《${c.bookName.trim()}》',
    ],
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

/// 关键词激活的原因：命中的主关键词，次级逻辑为「且含任一 / 且含全部」时附上
/// 命中的次级关键词；递归 / 扩大深度扫描时说明来源。
String _keywordReason(
  WorldBookEntry entry,
  String context,
  WorldBookSettings settings,
  _ScanState state,
) {
  bool hit(String k) =>
      k.trim().isNotEmpty &&
      WorldBookActivation.matchKey(context, k, entry, settings: settings);
  final primary = entry.keywords.firstWhere(hit, orElse: () => '');
  final buf = StringBuffer('关键词「${primary.trim()}」');
  if (entry.selective && entry.secondaryKeywords.isNotEmpty) {
    final secondary = entry.secondaryKeywords.where(hit).toList();
    switch (entry.secondaryLogic) {
      case WorldBookSecondaryLogic.andAny || WorldBookSecondaryLogic.andAll:
        if (secondary.isNotEmpty) {
          buf.write(' + 次级「${secondary.map((k) => k.trim()).join('、')}」');
        }
      case WorldBookSecondaryLogic.notAny:
        buf.write('，且不含任何次级关键词');
      case WorldBookSecondaryLogic.notAll:
        buf.write('，且未包含全部次级关键词');
    }
  }
  return switch (state) {
    _ScanState.recursion => '由其他条目内容触发：$buf',
    _ScanState.minActivations => '扩大扫描范围后命中：$buf',
    _ => buf.toString(),
  };
}

/// 粗略 token 估算（约 4 个 ASCII 字符或 1 个汉字算 1 个 token），编辑页显示
/// 条目大小也用它。
int worldBookRoughTokens(String text) {
  var ascii = 0;
  var other = 0;
  for (final r in text.runes) {
    r < 128 ? ascii++ : other++;
  }
  return (ascii / 4).ceil() + other;
}

/// 决定计时效果的指纹：只有改了**关键词、内容或计时设置**，正在进行的持续 /
/// 冷却才会重新开始；开关、顺序、位置、标题等改动不影响（ST 按整条目哈希，
/// 改任何字段都会重置，本应用放宽了）。
String worldBookTimerSignature(WorldBookEntry entry) => sha256
    .convert(
      utf8.encode(
        jsonEncode([
          entry.keywords,
          entry.secondaryKeywords,
          entry.content,
          entry.sticky,
          entry.cooldown,
          entry.delay,
        ]),
      ),
    )
    .toString();

/// [text] 里 `{{outlet::名字}}` 引用的名字（去空白、小写）。
Set<String> worldBookOutletNamesIn(Iterable<String?> texts) => {
  for (final t in texts)
    if (t != null)
      for (final m in RegExp(
        r'\{\{outlet::([^}]*)\}\}',
        caseSensitive: false,
      ).allMatches(t))
        if (m.group(1)!.trim().isNotEmpty) m.group(1)!.trim().toLowerCase(),
};
