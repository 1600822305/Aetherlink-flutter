import 'dart:ffi';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';

/// PDF 本地解析所需的 PDFium 原生库尚未安装。
class PdfiumEngineMissingException implements Exception {
  const PdfiumEngineMissingException();

  @override
  String toString() => 'PDF 解析引擎（PDFium）未安装';
}

/// 按需获取 PDFium 原生库的管理器（单例）。
///
/// libpdfium.so 不打进安装包（arm64 一份就有约 6MB，只有加 PDF 的用户才
/// 需要），改为首次使用时从云端下载官方预编译包、或由用户手动导入群里 /
/// 云盘分发的库文件。下载/导入后落盘到应用私有目录，之后离线可用。
class PdfiumEngineManager {
  PdfiumEngineManager._();

  static final PdfiumEngineManager instance = PdfiumEngineManager._();

  /// 与上游 pdfium_dart 0.2.5 构建钩子一致的 PDFium 版本。
  static const String pdfiumRelease = 'chromium/7811';

  /// 当前平台/架构对应的官方预编译包名后缀；不支持的平台返回 `null`。
  static String? get platformArchSuffix {
    final arch = switch (Abi.current()) {
      Abi.androidArm64 || Abi.linuxArm64 || Abi.macosArm64 => 'arm64',
      Abi.androidArm => 'arm',
      Abi.androidX64 ||
      Abi.linuxX64 ||
      Abi.macosX64 ||
      Abi.windowsX64 => 'x64',
      Abi.androidIA32 || Abi.windowsIA32 => 'x86',
      Abi.windowsArm64 => 'arm64',
      _ => null,
    };
    if (arch == null) return null;
    final os = Platform.isAndroid
        ? 'android'
        : Platform.isWindows
        ? 'win'
        : Platform.isMacOS
        ? 'mac'
        : Platform.isLinux
        ? 'linux'
        : null;
    if (os == null) return null;
    return '$os-$arch';
  }

  /// 官方预编译包（bblanchon/pdfium-binaries）的默认下载地址。
  /// UI 里允许换成任意直链（如国内云盘），支持 .tgz 或裸库文件。
  static Uri? get defaultDownloadUrl {
    final suffix = platformArchSuffix;
    if (suffix == null) return null;
    final release = Uri.encodeComponent(pdfiumRelease);
    return Uri.parse(
      'https://github.com/bblanchon/pdfium-binaries/releases/download/'
      '$release/pdfium-$suffix.tgz',
    );
  }

  static String get _libraryFileName => Platform.isWindows
      ? 'pdfium.dll'
      : Platform.isMacOS
      ? 'libpdfium.dylib'
      : 'libpdfium.so';

  bool _initialized = false;

  /// 引擎库的落盘路径（应用私有目录，卸载随应用清除）。
  Future<String> libraryPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'pdfium', _libraryFileName);
  }

  /// 引擎是否已安装（库文件已落盘）。
  Future<bool> isInstalled() async => File(await libraryPath()).exists();

  /// 初始化 pdfrx_engine 并指向已落盘的库；未安装时抛
  /// [PdfiumEngineMissingException]。
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    final path = await libraryPath();
    if (!File(path).existsSync()) throw const PdfiumEngineMissingException();
    Pdfrx.pdfiumModulePath ??= path;
    final tmp = await getTemporaryDirectory();
    await pdfrxInitialize(tmpPath: p.join(tmp.path, 'pdfrx.cache'));
    _initialized = true;
  }

  /// 从字节安装：自动识别 .tgz（官方发布包，抽出其中的库文件）或裸库文件，
  /// 落盘前先加载校验，无效内容抛 [FormatException]。
  Future<void> installFromBytes(Uint8List bytes) async {
    final library = await compute(_extractPdfiumLibrary, bytes);
    final path = await libraryPath();
    final file = File(path);
    await file.parent.create(recursive: true);
    final staging = File('$path.tmp');
    await staging.writeAsBytes(library, flush: true);
    try {
      _validateLibrary(staging.path);
    } catch (_) {
      await staging.delete();
      rethrow;
    }
    await staging.rename(path);
  }

  /// 从本地文件安装（手动导入：群里 / 云盘分发的 .tgz 或库文件）。
  Future<void> installFromFile(String sourcePath) async =>
      installFromBytes(await File(sourcePath).readAsBytes());

  /// 从 [url]（缺省为官方发布地址）下载并安装，[onProgress] 报告
  /// (已收字节, 总字节，未知时为 -1)。
  Future<void> download({
    Uri? url,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final target = url ?? defaultDownloadUrl;
    if (target == null) {
      throw UnsupportedError('当前平台没有可用的 PDFium 预编译包');
    }
    final response = await Dio().get<List<int>>(
      target.toString(),
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const FormatException('下载内容为空');
    }
    await installFromBytes(Uint8List.fromList(data));
  }

  /// 试加载并查找 PDFium 入口符号，验证库文件可用。
  void _validateLibrary(String path) {
    final DynamicLibrary lib;
    try {
      lib = DynamicLibrary.open(path);
    } catch (e) {
      throw FormatException('不是当前设备可加载的 PDFium 库：$e');
    }
    if (!lib.providesSymbol('FPDF_InitLibraryWithConfig')) {
      throw const FormatException('库文件缺少 PDFium 入口符号，可能架构不符或文件损坏');
    }
  }
}

/// 顶层函数（在 isolate 中跑）：从 .tgz 发布包里抽出库文件；
/// 非 gzip 内容视为裸库文件原样返回。
Uint8List _extractPdfiumLibrary(Uint8List bytes) {
  final isGzip = bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
  if (!isGzip) return bytes;
  final archive = TarDecoder().decodeBytes(
    const GZipDecoder().decodeBytes(bytes),
  );
  for (final name in const [
    'lib/libpdfium.so',
    'bin/pdfium.dll',
    'lib/libpdfium.dylib',
  ]) {
    final member = archive.findFile(name);
    if (member != null) return member.content;
  }
  throw const FormatException('压缩包里没有找到 PDFium 库文件');
}
