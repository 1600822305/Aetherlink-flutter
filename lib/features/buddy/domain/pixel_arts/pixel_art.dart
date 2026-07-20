// 像素图数据类型与共享调色板常量。每个物种一个文件（duck.dart …），
// 帽子在 hats.dart，pixel_arts.dart 汇总注册表。

/// 一张像素图：行字符串矩阵 + 字符调色板（ARGB int）。
/// 约定：`.` 透明，`E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。
class BuddyPixelArt {
  const BuddyPixelArt({required this.rows, required this.palette});

  final List<String> rows;
  final Map<String, int> palette;
}

/// 眼睛统一深棕黑。
const int kBuddyEyeColor = 0xFF2D2A26;

/// 腮红粉。
const int kBuddyBlushColor = 0xFFF4A6B0;
