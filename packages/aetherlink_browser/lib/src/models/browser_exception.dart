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

  /// 其他内部错误。
  internal,
}

class BrowserException implements Exception {
  const BrowserException(this.kind, this.message);

  final BrowserErrorKind kind;
  final String message;

  @override
  String toString() => 'BrowserException(${kind.name}): $message';
}
