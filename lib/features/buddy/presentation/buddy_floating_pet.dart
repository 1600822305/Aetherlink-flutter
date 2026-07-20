// App 内悬浮宠物：挂在 MaterialApp.builder 里浮在所有路由之上。
// 收起态是一颗迷你像素宠物胶囊（贴边吸附、可拖动），点按展开成
// 小卡片：像素动画 + 抚摸 + 碎碎念气泡 + 打开宠物页 + ✕ 关闭悬浮窗。

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/buddy/application/buddy_controller.dart';
import 'package:aetherlink_flutter/features/buddy/application/buddy_overlay_controller.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_phrases.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_types.dart';
import 'package:aetherlink_flutter/features/buddy/presentation/buddy_pixel_pet.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

/// 动画节拍（与宠物页一致，原版 TICK_MS = 500ms）。
const Duration _tick = Duration(milliseconds: 500);

/// 气泡显示时长（tick 数）与结尾渐隐窗口。
const int _bubbleShowTicks = 16;
const int _bubbleFadeTicks = 5;

/// 抚摸爱心持续 tick 数（原版 2.5s）。
const int _petBurstTicks = 5;

/// 悬浮宠物宿主：包一层 Stack 让宠物浮在 [child]（整个路由树）之上。
/// [visible] 由宿主决定（开关开 + 已孵化 + 不在宠物页）；关掉时零开销。
class BuddyFloatingPetHost extends ConsumerWidget {
  const BuddyFloatingPetHost({
    super.key,
    required this.child,
    required this.visible,
    required this.onOpenPage,
  });

  final Widget child;
  final bool visible;

  /// 跳转到宠物页（路由在宿主侧，组件不依赖 router）。
  final VoidCallback onOpenPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible) return child;
    final bones = ref.watch(buddyControllerProvider).bones;
    if (bones == null) return child;
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        child,
        _FloatingPet(bones: bones, onOpenPage: onOpenPage),
      ],
    );
  }
}

class _FloatingPet extends ConsumerStatefulWidget {
  const _FloatingPet({required this.bones, required this.onOpenPage});

  final BuddyBones bones;
  final VoidCallback onOpenPage;

  @override
  ConsumerState<_FloatingPet> createState() => _FloatingPetState();
}

class _FloatingPetState extends ConsumerState<_FloatingPet> {
  static const double _capsuleHeight = 48;
  static const double _expandedWidth = 200;

  final Random _random = Random();
  Timer? _timer;

  bool _expanded = false;
  bool _dragging = false;
  Offset _dragPosition = Offset.zero;

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
      // 收起态偶尔冒一句碎碎念（约 1%/tick ≈ 平均 ~50s 一句，别太吵）。
      if (_bubbleTicksLeft == 0 &&
          _petTicksLeft == 0 &&
          !_dragging &&
          _random.nextDouble() < 0.01) {
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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(buddyOverlayControllerProvider);
    final media = MediaQuery.of(context);
    final screen = media.size;

    final width = _expanded ? _expandedWidth : null;
    final top = _dragging
        ? _dragPosition.dy
        : settings.dy.clamp(
            media.padding.top + 8,
            screen.height - media.padding.bottom - 160,
          );

    Widget body = _expanded ? _buildExpanded(context) : _buildCapsule(context);

    // 拖动跟手：横向自由移动，松手吸附左右边缘并持久化。
    body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => setState(() {
        _dragging = true;
        _dragPosition = Offset(
          settings.snapLeft ? 0 : screen.width - (width ?? 120),
          top.toDouble(),
        );
      }),
      onPanUpdate: (d) => setState(() => _dragPosition += d.delta),
      onPanEnd: (_) {
        final snapLeft = _dragPosition.dx + (width ?? 120) / 2 < screen.width / 2;
        ref.read(buddyOverlayControllerProvider.notifier).setPosition(
              dy: _dragPosition.dy,
              snapLeft: snapLeft,
            );
        setState(() => _dragging = false);
      },
      child: body,
    );

    if (_dragging) {
      return Positioned(left: _dragPosition.dx, top: _dragPosition.dy, child: body);
    }
    return Positioned(
      left: settings.snapLeft ? 8 : null,
      right: settings.snapLeft ? null : 8,
      top: top.toDouble(),
      child: body,
    );
  }

  /// 收起态：迷你像素宠物胶囊（+ 头顶小气泡）。
  Widget _buildCapsule(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_bubbleText != null) _bubble(theme, maxWidth: 180),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_capsuleHeight / 2),
            onTap: () {
              Haptics.instance.soft();
              setState(() => _expanded = true);
            },
            child: Container(
              height: _capsuleHeight,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(_capsuleHeight / 2),
                border: Border.all(color: theme.dividerColor),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: BuddyPixelPet(
                  bones: widget.bones,
                  size: _capsuleHeight - 10,
                  petTrigger: _petTrigger,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 展开态：小卡片（像素动画 + 名字 + 抚摸/详情/关闭）。
  Widget _buildExpanded(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final soul = ref.watch(buddyControllerProvider).soul;
    final bones = widget.bones;

    return Container(
      width: _expandedWidth,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：名字 + 收起 + 关闭。
          Container(
            padding: const EdgeInsets.only(left: 12, right: 4),
            color: cs.onSurface.withValues(alpha: 0.015),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    soul?.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: const Icon(LucideIcons.minimize2, size: 15),
                  color: cs.onSurface.withValues(alpha: 0.6),
                  onPressed: () => setState(() => _expanded = false),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: const Icon(LucideIcons.x, size: 16),
                  color: cs.onSurface.withValues(alpha: 0.6),
                  // 悬浮窗内直接关闭：同步关掉宠物页里的开关。
                  onPressed: () => ref
                      .read(buddyOverlayControllerProvider.notifier)
                      .setEnabled(false),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          if (_bubbleText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: _bubble(theme, maxWidth: _expandedWidth - 20),
            ),
          // 宠物：点按 = 抚摸。
          GestureDetector(
            onTap: _pet,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: BuddyPixelPet(
                  bones: bones,
                  size: 96,
                  petTrigger: _petTrigger,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _pet,
                  icon: const Icon(LucideIcons.hand, size: 14),
                  label: const Text('抚摸', style: TextStyle(fontSize: 12)),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: widget.onOpenPage,
                  icon: const Icon(LucideIcons.pawPrint, size: 14),
                  label: const Text('详情', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(ThemeData theme, {required double maxWidth}) {
    final cs = theme.colorScheme;
    return AnimatedOpacity(
      opacity: _bubbleTicksLeft <= _bubbleFadeTicks ? 0.4 : 1,
      duration: _tick,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Text(
          _bubbleText ?? '',
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
