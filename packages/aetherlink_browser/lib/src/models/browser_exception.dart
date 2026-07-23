/// 面向模型的浏览器错误分类（设计稿 §18.1/§19）：消息直接回填给模型，
/// 需可读、可指导下一步动作。
enum BrowserErrorKind {
  /// URL 被安全策略拒绝（协议/禁止网段），换 URL 重试。
  blockedUrl,

  /// 导航/加载超时——会话保留，页面可能部分可读，可继续 read/snapshot。
  navigationTimeout,

  /// 页面内 JS 执行超时/失败（提取脚本挂死）。
  scriptTimeout,

  /// 网络层失败（DNS/连接）。
  network,

  /// 会话已失效（WebView 已回收/重建），应重新 open。
  sessionGone,

  /// 元素未找到/定位方式无效（permanent：换定位方式或先重新快照）。
  elementNotFound,

  /// @N ref 已失效（页面已导航/快照已重建），应重新 browser_snapshot_dom。
  refStale,

  /// 会话由用户控制中（已 hand off / 用户接管）——硬停止：不得重试
  /// 绕过，需等用户交回（browser_take_over）或换会话。
  userControlled,

  /// 会话数达到上限且没有可回收的空闲会话。
  sessionLimit,

  /// 其他内部错误。
  internal,
}

class BrowserException implements Exception {
  const BrowserException(this.kind, this.message, {this.transient = false});

  final BrowserErrorKind kind;
  final String message;

  /// 瞬态失败（可原样小重试，如页面未加载完）；false 为 permanent，
  /// 应换策略而非重试（借 ego-lite element-resolver 的失败分类语义）。
  final bool transient;

  @override
  String toString() => 'BrowserException(${kind.name}): $message';
}
