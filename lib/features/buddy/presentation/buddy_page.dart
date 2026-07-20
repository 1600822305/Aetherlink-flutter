// 电子宠物页面：孵化 → 精灵动画 + 抚摸 + 台词气泡 + 属性卡片 + 悬浮窗开关。
// 玩法移植自 Claude Code 的 BUDDY 隐藏功能（终端拓麻歌子），骨架由种子
// 确定性生成（见 buddy_engine.dart），台词走本地台词库。
// UI 采用项目统一的设置页风格：紧凑 AppBar + 描边卡片 + 头部条 + 行内开关。

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/buddy/application/buddy_controller.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_phrases.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_types.dart';
import 'package:aetherlink_flutter/features/buddy/domain/pixel_arts/pixel_arts.dart';
import 'package:aetherlink_flutter/features/buddy/presentation/buddy_pixel_pet.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

/// 动画节拍（原版 TICK_MS = 500ms）。
const Duration _tick = Duration(milliseconds: 500);

/// 气泡显示时长（原版 ~10s）与结尾渐隐窗口（~3s）。
const int _bubbleShowTicks = 20;
const int _bubbleFadeTicks = 6;

/// 抚摸台词冷却（爱心/挤压动画由 [BuddyPixelPet] 自己驱动）。
const int _petBurstTicks = 5;

Color _rarityColor(BuddyRarity rarity, ColorScheme cs) {
  switch (rarity) {
    case BuddyRarity.common:
      return cs.onSurface.withValues(alpha: 0.5);
    case BuddyRarity.uncommon:
      return const Color(0xFF22C55E);
    case BuddyRarity.rare:
      return const Color(0xFF3B82F6);
    case BuddyRarity.epic:
      return const Color(0xFF8B5CF6);
    case BuddyRarity.legendary:
      return const Color(0xFFF59E0B);
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

  int _petTicksLeft = 0;
  int _petTrigger = 0;
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
    Haptics.instance.light();
    setState(() {
      _petTicksLeft = _petBurstTicks;
      _petTrigger++;
      _say(pickBuddyPhrase(_random, kBuddyPetReactions));
    });
  }

  void _chat() {
    setState(() => _say(pickBuddyPhrase(_random, kBuddyIdleChatter)));
  }

  void _hatch() {
    Haptics.instance.medium();
    ref.read(buddyControllerProvider.notifier).hatch();
    setState(() => _say(pickBuddyPhrase(_random, kBuddyHatchGreetings)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(buddyControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRouter.chatPath),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('宠物'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints.tightFor(width: 40, height: 40),
              icon: const Icon(LucideIcons.settings, size: 20),
              color: theme.colorScheme.onSurface,
              onPressed: () => context.push(AppRouter.buddySettingsPath),
            ),
          ),
        ],
      ),
      body: !state.loaded
          ? const Center(child: CircularProgressIndicator())
          : state.soul == null
              ? _HatchView(onHatch: _hatch)
              : _buildPetView(theme, state.soul!, state.bones!),
    );
  }

  Widget _buildPetView(ThemeData theme, BuddySoul soul, BuddyBones bones) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _spriteCard(theme, soul, bones),
        const SizedBox(height: 16),
        _infoCard(theme, soul, bones),
      ],
    );
  }

  /// 精灵卡片：气泡 + 动画 + 名字/稀有度 + 抚摸/聊天。
  Widget _spriteCard(ThemeData theme, BuddySoul soul, BuddyBones bones) {
    final cs = theme.colorScheme;

    return _OutlinedCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: _bubbleText == null
                  ? null
                  : Center(
                      child: AnimatedOpacity(
                        opacity:
                            _bubbleTicksLeft <= _bubbleFadeTicks ? 0.4 : 1,
                        duration: _tick,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Text(_bubbleText!,
                              style: theme.textTheme.bodySmall),
                        ),
                      ),
                    ),
            ),
            GestureDetector(
              onTap: _pet,
              behavior: HitTestBehavior.opaque,
              child: BuddyPixelPet(
                bones: bones,
                size: 160,
                petTrigger: _petTrigger,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bones.shiny ? '✨ ${soul.name} ✨' : soul.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${bones.rarity.stars} ${bones.rarity.label} · ${bones.species.label}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: _rarityColor(bones.rarity, cs)),
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
          ],
        ),
      ),
    );
  }

  /// 宠物卡片：性格 / 孵化时间 / 帽子 / 五维属性条。
  Widget _infoCard(ThemeData theme, BuddySoul soul, BuddyBones bones) {
    final cs = theme.colorScheme;
    final hatched = DateTime.fromMillisecondsSinceEpoch(soul.hatchedAt);
    final hatchedLabel =
        '${hatched.year}-${hatched.month.toString().padLeft(2, '0')}-${hatched.day.toString().padLeft(2, '0')}';

    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: '宠物卡片', description: rarityFlavor(bones.rarity)),
          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kvRow(theme, '性格', soul.personality),
                const SizedBox(height: 8),
                _kvRow(theme, '孵化于', hatchedLabel),
                if (bones.hat != BuddyHat.none) ...[
                  const SizedBox(height: 8),
                  _kvRow(theme, '帽子', bones.hat.label),
                ],
                const SizedBox(height: 12),
                Divider(height: 1, color: theme.dividerColor),
                const SizedBox(height: 8),
                for (final stat in BuddyStat.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvRow(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// 孵化视图：一颗蛋 + 孵化按钮。
class _HatchView extends StatelessWidget {
  const _HatchView({required this.onHatch});

  final VoidCallback onHatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BuddyPixelArtView(art: kBuddyEggArt, size: 120),
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

/// 描边卡片：与设置页 `_OutlinedCard` 同款（surface + 16 圆角 + divider 描边
/// + 轻阴影）。
class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 卡片头部条：与设置页 `_CardHeader` 同款（微染色条 + 标题 + 描述）。
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
