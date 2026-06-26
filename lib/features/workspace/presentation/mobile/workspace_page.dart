// Workspace P0 skeleton: three full-screen pages swiped horizontally like the
// sidebar's "push" reveal — 文件树 / 文件查看(空时为设置工作区起始屏) / 待定第三页.
//
// This is intentionally content-free: each page is a solid color block so the
// full-screen push/swipe motion can be evaluated before any real UI lands. The
// middle page is the default landing page; swipe left → 文件树, swipe right →
// 第三页(占位,内容待定). 工作区是纯文件域,不内嵌智能体;智能体是独立模块,
// 仅复用底层能力层(WorkspaceBackend / MCP).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  // Land on the middle page (文件查看 / 设置工作区).
  static const int _initialPage = 1;

  late final PageController _controller =
      PageController(initialPage: _initialPage);

  int _page = _initialPage;

  static const List<_WorkspacePane> _panes = [
    _WorkspacePane(label: '文件树', color: Color(0xFF1E3A5F)),
    _WorkspacePane(label: '文件查看 / 设置工作区', color: Color(0xFF1F4D3A)),
    _WorkspacePane(label: '第三页(待定)', color: Color(0xFF4A2D5F)),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Edge-to-edge: 色块铺满整屏(延伸到状态栏/导航栏后面),不包 SafeArea。
    // 只给顶部控制行单独保留安全区内边距,避免被状态栏遮挡。
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _panes.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final pane = _panes[i];
              return Container(
                color: pane.color,
                alignment: Alignment.center,
                child: Text(
                  pane.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          // 顶部返回 + 页码指示，方便看清当前停在哪一页。
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  _CircleButton(
                    icon: LucideIcons.arrowLeft,
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  _PageDots(count: _panes.length, active: _page),
                  const Spacer(),
                  const SizedBox(width: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspacePane {
  const _WorkspacePane({required this.label, required this.color});

  final String label;
  final Color color;
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.25),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
