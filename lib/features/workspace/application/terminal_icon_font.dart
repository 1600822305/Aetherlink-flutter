// 终端图标字体（Symbols Nerd Font Mono）按需下载：不打进安装包（约 2.6MB），
// 首次打开终端视图时后台下载到应用私有目录并用 FontLoader 注册，之后离线可用。
//
// xterm3 的 fontFamilyFallback 已列入「Symbols Nerd Font Mono」，注册后
// oh-my-zsh / starship / lsd 等主题的图标不再显示为方块；FontLoader 加载会
// 触发 systemFontsDidChange，xterm 渲染器自动清字形缓存重绘，无需额外通知。
// 下载失败静默（图标仍为方块），下次打开终端再试。

import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 与 xterm3 默认 fontFamilyFallback 里的族名一致。
const String kTerminalIconFontFamily = 'Symbols Nerd Font Mono';

const String _kNerdFontsVersion = 'v3.4.0';
const String _kFontFileName = 'SymbolsNerdFontMono-Regular.ttf';

/// 下载源（按顺序尝试）：jsDelivr 国内可达性较好，直取 ttf；GitHub
/// Release 为官方源（zip，需解出 ttf）。
const List<String> kTerminalIconFontUrls = [
  'https://cdn.jsdelivr.net/gh/ryanoasis/nerd-fonts@$_kNerdFontsVersion/'
      'patched-fonts/NerdFontsSymbolsOnly/$_kFontFileName',
  'https://github.com/ryanoasis/nerd-fonts/releases/download/'
      '$_kNerdFontsVersion/NerdFontsSymbolsOnly.zip',
];

/// 合法字体文件最小体积（防把错误页 / 半截文件当字体落盘）。
const int _kMinFontBytes = 100 * 1024;

class TerminalIconFont {
  TerminalIconFont._();

  static final TerminalIconFont instance = TerminalIconFont._();

  Future<bool>? _pending;
  bool _loaded = false;

  /// 已注册到当前进程。
  bool get isLoaded => _loaded;

  /// 字体缓存路径（应用私有目录，卸载随应用清除）。
  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'terminal_fonts', _kFontFileName));
  }

  /// 确保字体已注册：有缓存直接加载，没有就后台下载。并发调用共用一次；
  /// 失败返回 false 且允许下次重试。终端视图打开时 fire-and-forget 调用。
  Future<bool> ensureLoaded() {
    if (_loaded) return Future.value(true);
    return _pending ??= _load().then((ok) {
      _pending = null;
      return ok;
    });
  }

  Future<bool> _load() async {
    try {
      final file = await _cacheFile();
      Uint8List? bytes;
      if (file.existsSync() && file.lengthSync() >= _kMinFontBytes) {
        bytes = await file.readAsBytes();
      } else {
        bytes = await _download();
        if (bytes == null) return false;
        await file.parent.create(recursive: true);
        final staging = File('${file.path}.tmp');
        await staging.writeAsBytes(bytes, flush: true);
        await staging.rename(file.path);
      }
      final loader = FontLoader(kTerminalIconFontFamily)
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loaded = true;
      return true;
    } catch (e) {
      debugPrint('终端图标字体加载失败：$e');
      return false;
    }
  }

  Future<Uint8List?> _download() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        responseType: ResponseType.bytes,
      ),
    );
    for (final url in kTerminalIconFontUrls) {
      try {
        final resp = await dio.get<List<int>>(url);
        final data = resp.data;
        if (data == null || data.isEmpty) continue;
        final raw = Uint8List.fromList(data);
        final font = url.endsWith('.zip')
            ? await compute(extractTerminalIconFont, raw)
            : raw;
        if (font != null && isTrueTypeFont(font)) return font;
      } catch (e) {
        debugPrint('终端图标字体下载失败（$url）：$e');
      }
    }
    return null;
  }
}

/// 校验是 TrueType / OpenType 字体且体积合理（而不是 HTML 错误页）。
@visibleForTesting
bool isTrueTypeFont(Uint8List bytes) {
  if (bytes.length < _kMinFontBytes) return false;
  final tag = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  return tag == 0x00010000 || // TrueType
      tag == 0x4F54544F || // 'OTTO'
      tag == 0x74727565; // 'true'
}

/// 顶层函数（isolate 中跑）：从发布 zip 里抽出 Mono 版 ttf。
@visibleForTesting
Uint8List? extractTerminalIconFont(Uint8List zipBytes) {
  try {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    for (final f in archive.files) {
      if (f.isFile && p.basename(f.name) == _kFontFileName) {
        return Uint8List.fromList(f.content as List<int>);
      }
    }
  } catch (_) {}
  return null;
}
