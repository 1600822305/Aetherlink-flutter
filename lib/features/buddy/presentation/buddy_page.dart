// 电子宠物页面：孵化 → 精灵动画 + 抚摸 + 台词气泡 + 属性卡片。
// 玩法移植自 Claude Code 的 BUDDY 隐藏功能（终端拓麻歌子），骨架由种子
// 确定性生成（见 buddy_engine.dart），台词走本地台词库。

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/buddy/application/buddy_controller.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_phrases.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_sprites.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_types.dart';

/// 动画节拍（原版 TICK_MS = 500ms）。
const Duration _tick = Duration(milliseconds: 500);

/// 气泡显示时长（原版 ~10s）与结尾渐隐窗口（~3s）。
const int _bubbleShowTicks = 20;
const int _bubbleFadeTicks = 6;

/// 抚摸爱心动画时长（原版 PET_BURST_MS = 2.5s → 5 ticks）。
const int _petBurstTicks = 5;

/// 爱心上浮帧（原版 PET_HEARTS，figures.heart → ♥）。
const List<String> _petHearts = [
  '   ♥    ♥   ',
  '  ♥  ♥   ♥  ',
  ' ♥   ♥  ♥   ',
  '♥  ♥      ♥ ',
  '·    ·   ·  ',
];

Color _rarityColor(BuddyRarity rarity, ColorScheme cs) {
  switch (rarity) {
    case BuddyRarity.common:
      return cs.onSurface.withValues(alpha: 0.5);
    case BuddyRarity.uncommon:
      return Colors.green;
    case BuddyRarity.rare:
      return Colors.blue;
    case BuddyRarity.epic:
      return Colors.purple;
    case BuddyRarity.legendary:
      return Colors.amber.shade700;
  }
}

class BuddyPage extends ConsumerStatefulWidget {
  const BuddyPage({super.key});

  @override
  ConsumerState<BuddyPage> createState() => _BuddyPageState();
}

class _BuddyPageState extends ConsumerState<BuddyPage> {
  Timer? _timer;
  final Random _random = Random();

  int _tickCount = 0;
  int _petTicksLeft = 0;
  String? _bubbleText;
  int _bubbleTicksLeft = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) => _onTick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {
      _tickCount++;
      if (_petTicksLeft > 0) _petTicksLeft--;
      if (_bubbleTicksLeft > 0) {
        _bubbleTicksLeft--;
        if (_bubbleTicksLeft == 0) _bubbleText = null;
      }
      // 偶尔自言自语（空闲且无气泡时约每 tick 2% 概率 ≈ 平均 ~25s 一句）。
      if (_bubbleTicksLeft == 0 &&
          _petTicksLeft == 0 &&
          _random.nextDouble() < 0.02) {
        _say(pickBuddyPhrase(_random, kBuddyIdleChatter));
      }
    });
  }

  void _say(String text) {
    _bubbleText = text;
    _bubbleTicksLeft = _bubbleShowTicks;
  }

  void _pet() {
    setState(() {
      _petTicksLeft = _petBurstTicks;
      _say(pickBuddyPhrase(_random, kBuddyPetReactions));
    });
  }

  void _chat() {
    setState(() => _say(pickBuddyPhrase(_random, kBuddyIdleChatter)));
  }

  void _hatch() {
    ref.read(buddyControllerProvider.notifier).hatch();
    setState(() => _say(pickBuddyPhrase(_random, kBuddyHatchGreetings)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(buddyControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('宠物'), centerTitle: true),
      body: !state.loaded
          ? const Center(child: CircularProgressIndicator())
          : state.soul == null
              ? _HatchView(onHatch: _hatch)
              : _buildPetView(theme, state.soul!, state.bones!),
    );
  }

  Widget _buildPetView(ThemeData theme, BuddySoul soul, BuddyBones bones) {
    final cs = theme.colorScheme;

    // 空闲序列：大部分静止、偶尔 fidget、偶尔眨眼；被摸/说话时快速循环。
    final active = _petTicksLeft > 0 || _bubbleTicksLeft > _bubbleFadeTicks;
    final int seq = active
        ? _tickCount % buddyFrameCount(bones.species)
        : kBuddyIdleSequence[_tickCount % kBuddyIdleSequence.length];
    final blink = seq == -1;
    final frame = blink ? 0 : seq;

    final spriteLines = renderBuddySprite(bones, frame: frame, blink: blink);
    final heartLine = _petTicksLeft > 0
        ? _petHearts[(_petBurstTicks - _petTicksLeft) % _petHearts.length]
        : null;

    final spriteColor =
        bones.shiny ? Colors.amber.shade700 : cs.onSurface;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 气泡 ────────────────────────────────────────────────────────
        SizedBox(
          height: 64,
          child: _bubbleText == null
              ? null
              : Center(
                  child: AnimatedOpacity(
                    opacity: _bubbleTicksLeft <= _bubbleFadeTicks ? 0.4 : 1,
                    duration: _tick,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: cs.onSurface.withValues(alpha: 0.15)),
                      ),
                      child: Text(_bubbleText!,
                          style: theme.textTheme.bodyMedium),
                    ),
                  ),
                ),
        ),
        // ── 精灵 ────────────────────────────────────────────────────────
        GestureDetector(
          onTap: _pet,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              if (heartLine != null)
                Text(
                  heartLine,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    height: 1.1,
                    color: Colors.pink,
                  ),
                ),
              Text(
                spriteLines.join('\n'),
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  height: 1.15,
                  color: spriteColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            bones.shiny ? '✨ ${soul.name} ✨' : soul.name,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Center(
          child: Text(
            '${bones.rarity.stars} ${bones.rarity.label} · ${bones.species.label}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: _rarityColor(bones.rarity, cs)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: _pet,
              icon: const Icon(LucideIcons.hand, size: 16),
              label: const Text('抚摸'),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: _chat,
              icon: const Icon(LucideIcons.messageCircle, size: 16),
              label: const Text('聊天'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _InfoCard(soul: soul, bones: bones),
      ],
    );
  }
}

/// 孵化视图：一颗蛋 + 孵化按钮。
class _HatchView extends StatelessWidget {
  const _HatchView({required this.onHatch});

  final VoidCallback onHatch;

  static const String _egg = '   .-"-.\n'
      '  /     \\\n'
      ' |  ? ?  |\n'
      '  \\     /\n'
      "   `---´";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _egg,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 24,
              height: 1.2,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text('有一颗蛋在等你……', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 6),
          Text(
            '物种和稀有度在孵化瞬间注定，独一无二。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onHatch,
            icon: const Icon(LucideIcons.egg, size: 18),
            label: const Text('孵化'),
          ),
        ],
      ),
    );
  }
}

/// 宠物卡片：性格 / 孵化时间 / 五维属性条。
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.soul, required this.bones});

  final BuddySoul soul;
  final BuddyBones bones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hatched = DateTime.fromMillisecondsSinceEpoch(soul.hatchedAt);
    final hatchedLabel =
        '${hatched.year}-${hatched.month.toString().padLeft(2, '0')}-${hatched.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('性格', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(soul.personality, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(rarityFlavor(bones.rarity),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _rarityColor(bones.rarity, cs),
              )),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('孵化于 $hatchedLabel', style: theme.textTheme.bodySmall),
              const Spacer(),
              if (bones.hat != BuddyHat.none)
                Text('帽子：${bones.hat.label}',
                    style: theme.textTheme.bodySmall),
            ],
          ),
          const Divider(height: 24),
          for (final stat in BuddyStat.values) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(stat.label,
                        style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (bones.stats[stat] ?? 0) / 100,
                        minHeight: 8,
                        backgroundColor:
                            cs.onSurface.withValues(alpha: 0.08),
                        color: _rarityColor(bones.rarity, cs),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${bones.stats[stat] ?? 0}',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
