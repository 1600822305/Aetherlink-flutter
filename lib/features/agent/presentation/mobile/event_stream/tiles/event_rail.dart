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
    // 用 Stack 让左轨随内容高度铺满，而不是 IntrinsicHeight + stretch：
    // 事件行里的 Markdown 表格单元格是 LayoutBuilder（不支持 intrinsic
    // 测量协议），IntrinsicHeight 会把行高算小，表格被裁掉显示不全。
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 28,
          child: Column(
            children: [
              const SizedBox(height: 4),
              node,
              Expanded(child: Container(width: 1.5, color: lineColor)),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 12),
            child: child,
          ),
        ),
      ],
    );
  }
}
