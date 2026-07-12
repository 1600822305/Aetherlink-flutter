// 编辑器自动保存的防抖策略（纯 Dart，桌面端可复用）：每次编辑重置计时，
// 停顿 [AutoSaveDebouncer.delay] 后触发一次保存回调。「能不能保存」
// （dirty / 可写 / 是否处于外部修改冲突）由 UI 侧判断后再调用。

import 'dart:async';

/// 自动保存延时的可选档位（秒），设置页分段选择。
const List<int> kAutoSaveDelayOptions = [1, 3, 10];

/// 自动保存延时默认值（秒）。
const int kAutoSaveDefaultDelaySecs = 3;

/// 编辑防抖器：[notifyEdit] 重置计时，停顿 [delay] 后触发 [onFire]。
class AutoSaveDebouncer {
  AutoSaveDebouncer({required this.delay, required this.onFire});

  final Duration delay;
  final void Function() onFire;

  Timer? _timer;

  bool get isPending => _timer?.isActive ?? false;

  /// 记录一次编辑，重置计时。
  void notifyEdit() {
    _timer?.cancel();
    _timer = Timer(delay, onFire);
  }

  /// 取消未触发的保存（手动保存 / 退出编辑 / 关闭文件时调用）。
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
