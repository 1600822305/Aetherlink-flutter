import 'package:freezed_annotation/freezed_annotation.dart';

part 'font_settings.freezed.dart';
part 'font_settings.g.dart';

/// 字体来源 (combining kelivo 的原生机制 + web 的产品形态)：
///   * [system] 系统已安装字体（通过 `system_fonts` 加载）；
///   * [google] Google Fonts 在线字体（通过 `google_fonts` 运行时拉取）；
///   * [local] 用户导入的本地字体文件（`file_picker` → `FontLoader`）。
enum FontSource {
  system('system'),
  google('google'),
  local('local');

  const FontSource(this.id);

  /// The string id persisted in the font settings JSON blob.
  final String id;

  static FontSource fromId(String? id) {
    for (final v in FontSource.values) {
      if (v.id == id) return v;
    }
    return FontSource.system;
  }
}

/// 单个字体维度的选择（应用字体或代码字体共用此结构）。
///
/// [family] 为空表示「使用平台默认字体」（应用字体）或等宽回退（代码字体）。
/// [path] 仅本地字体使用，指向 app 目录下复制的字体文件，用于启动时通过
/// `FontLoader` 重新注册。本地字体的 `FontLoader` alias 即 [family]。
@freezed
abstract class FontSelection with _$FontSelection {
  const factory FontSelection({
    @Default(FontSource.system) FontSource source,
    @Default('') String family,
    @Default('') String path,
  }) = _FontSelection;

  factory FontSelection.fromJson(Map<String, dynamic> json) =>
      _$FontSelectionFromJson(json);
}

/// 全局字体配置：两个维度（应用字体 + 代码字体），各自可来自系统 / Google /
/// 本地三类来源。作为单个 JSON blob 持久化（对齐 web 的 `settings` slice）。
@freezed
abstract class FontSettings with _$FontSettings {
  const factory FontSettings({
    @Default(FontSelection()) FontSelection appFont,
    @Default(FontSelection()) FontSelection codeFont,
  }) = _FontSettings;

  factory FontSettings.fromJson(Map<String, dynamic> json) =>
      _$FontSettingsFromJson(json);
}
