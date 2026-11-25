import 'package:flutter/widgets.dart';

/// 横向翻页容器（PageView）的临时禁滑锁。
///
/// 由翻页容器自己持有并经 [PageSwipeLockScope] 下发给子树；子组件
/// （如终端拖选）按需 [acquire] / [release]。用持有者集合而非 bool：
/// 每个持有者只负责释放自己，任何一方销毁都不会让锁卡死。
class PageSwipeLock extends ChangeNotifier {
  final Set<Object> _holders = {};

  bool get locked => _holders.isNotEmpty;

  void acquire(Object holder) {
    if (_holders.add(holder)) notifyListeners();
  }

  void release(Object holder) {
    if (_holders.remove(holder)) notifyListeners();
  }

  /// 最近的翻页容器的锁；不在任何翻页容器里时为 null。
  static PageSwipeLock? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PageSwipeLockScope>()
      ?.lock;
}

/// 把 [lock] 下发给子树。锁本身的变化不触发子树重建（只有换了锁实例才通知）。
class PageSwipeLockScope extends InheritedWidget {
  const PageSwipeLockScope({
    required this.lock,
    required super.child,
    super.key,
  });

  final PageSwipeLock lock;

  @override
  bool updateShouldNotify(PageSwipeLockScope oldWidget) =>
      !identical(lock, oldWidget.lock);
}
