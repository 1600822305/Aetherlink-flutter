/// 截图体积控制选项（设计稿 §17.2）：分辨率是最大杠杆，默认限
/// 视口宽 + JPEG 压缩，一张图控制在几百 token 量级。
class SnapshotOptions {
  const SnapshotOptions({
    this.maxWidth = 1024,
    this.jpegQuality = 70,
    this.fullPage = false,
  });

  /// 视口/输出宽度上限（px），长边随比例缩放。
  final int maxWidth;

  /// JPEG 压缩质量（0-100）。
  final int jpegQuality;

  /// true 截整页（长页体积大，谨慎），false 只截当前视口。
  final bool fullPage;
}
