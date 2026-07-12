import 'package:flutter/material.dart';

/// 时间线左轨：一条纵线贯穿 + 节点（形状/颜色由各事件行提供，
/// UI 稿 §4.1「时间线左轨」）。
class EventRail extends StatelessWidget {
  const EventRail({required this.node, required this.child, super.key});

  final Widget node;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lineColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.12);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 4),
                node,
                Expanded(child: Container(width: 1.5, color: lineColor)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
