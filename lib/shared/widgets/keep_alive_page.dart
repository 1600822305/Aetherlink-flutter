import 'package:flutter/widgets.dart';

/// 横向翻页容器（PageView）的子页保活包装。
///
/// PageView 默认只保留视口内的页，滑出去的页会被销毁、再滑入时在拖动途中
/// 重新 build 整棵子树；重页面（事件流、终端、diff）因此每次横滑都掉帧。
class KeepAlivePage extends StatefulWidget {
  const KeepAlivePage({required this.child, super.key});

  final Widget child;

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
