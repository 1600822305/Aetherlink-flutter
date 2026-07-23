/// 交互动作（click/fill/select）的结果（升级设计 §2.2 M4b）：
/// 动作是否触发了导航 + 动作后的页面状态，避免"点了但不知道跳没跳"。
class InteractResult {
  const InteractResult({
    required this.navigated,
    required this.url,
    required this.title,
  });

  /// 动作是否触发了页面导航（已等待新页面加载完成或超时截停）。
  final bool navigated;

  /// 动作后的当前页面 URL。
  final String url;

  /// 动作后的页面标题。
  final String title;
}

/// waitFor 的等待条件（三选一，至少提供一个）。
class WaitForCondition {
  const WaitForCondition({this.selector, this.urlContains, this.jsPredicate});

  /// 等待该定位目标（@N/role:/CSS）出现且可见。
  final String? selector;

  /// 等待当前 URL 包含该子串。
  final String? urlContains;

  /// 等待该 JS 表达式求值为真。
  final String? jsPredicate;

  bool get isEmpty =>
      selector == null && urlContains == null && jsPredicate == null;
}
