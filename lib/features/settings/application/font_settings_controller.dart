import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:system_fonts/system_fonts.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/font_settings.dart';

part 'font_settings_controller.g.dart';

/// Storage key for the persisted 全局字体 settings (a single JSON blob, mirroring
/// how the other appearance settings live under the `settings` slice).
const String kFontSettingKey = 'fontSettings';

/// Asset bundling the Google Fonts catalog metadata (family → style category and
/// the subset of families that ship CJK glyphs), used to group / filter the
/// Google Fonts picker the way the original web product does.
const String _kGoogleFontMetaAsset = 'assets/fonts/google_font_categories.json';

/// A Google Fonts family with the metadata the picker groups / filters by.
class GoogleFontInfo {
  const GoogleFontInfo({
    required this.family,
    required this.category,
    required this.cjk,
  });

  final String family;

  /// One of `sans-serif` / `serif` / `monospace` / `display` / `handwriting`.
  final String category;

  /// Whether the family ships CJK glyphs (so it actually changes Chinese text).
  final bool cjk;
}

/// Loads and registers fonts for the three supported sources, the Flutter-native
/// port of kelivo's font mechanism:
///   * 系统字体 → `system_fonts`（扫描系统字体目录并注册）；
///   * Google Fonts → Google Fonts CSS API（HTTP 拉取 ttf + 缓存 + `FontLoader`）；
///   * 本地字体 → `file_picker` 选取 → 复制进 app 目录 → `FontLoader` 注册。
class FontLoaderService {
  /// The directory under the app's documents folder where imported local font
  /// files are copied, so they survive restarts and can be re-registered.
  Future<Directory> _fontsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'fonts'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// The installed system font family names (sorted), used to populate the
  /// 系统字体 picker.
  List<String> systemFonts() => SystemFonts().getFontList()..sort();

  /// The full Google Fonts catalog family names (sorted), used to populate the
  /// Google Fonts picker. Sourced from the bundled metadata once it is loaded.
  List<String> googleFonts() {
    final keys = _gfCategories?.keys.toList();
    if (keys == null) return const [];
    keys.sort();
    return keys;
  }

  Map<String, String>? _gfCategories;
  Set<String>? _gfCjk;

  /// Loads the bundled Google Fonts catalog metadata once and caches it (family
  /// → style category, plus the subset of families that ship CJK glyphs).
  Future<void> _ensureGfMeta() async {
    if (_gfCategories != null && _gfCjk != null) return;
    final raw = await rootBundle.loadString(_kGoogleFontMetaAsset);
    final meta = jsonDecode(raw) as Map<String, dynamic>;
    _gfCategories = (meta['categories'] as Map).map(
      (k, v) => MapEntry(k as String, v as String),
    );
    _gfCjk = ((meta['cjk'] as List).cast<String>()).toSet();
  }

  /// The full Google Fonts catalog tagged with style category + CJK support,
  /// sorted by family. The family list comes from the bundled metadata (it is
  /// the font catalog now that the `google_fonts` package is gone).
  Future<List<GoogleFontInfo>> googleFontsCategorized() async {
    await _ensureGfMeta();
    final categories = _gfCategories!;
    final cjk = _gfCjk!;
    final out = [
      for (final family in categories.keys)
        GoogleFontInfo(
          family: family,
          category: categories[family] ?? 'sans-serif',
          cjk: cjk.contains(family),
        ),
    ]..sort((a, b) => a.family.compareTo(b.family));
    return out;
  }

  /// The previously imported local fonts (one per file under the app fonts dir),
  /// re-registered so they render in the picker preview, used to populate the
  /// 本地字体 picker.
  Future<List<FontSelection>> localFonts() async {
    final dir = await _fontsDir();
    final out = <FontSelection>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.ttf' && ext != '.otf' && ext != '.ttc') continue;
      final alias = p.basenameWithoutExtension(entity.path);
      await _registerLocal(alias, entity.path);
      out.add(
        FontSelection(
          source: FontSource.local,
          family: alias,
          path: entity.path,
        ),
      );
    }
    out.sort((a, b) => a.family.compareTo(b.family));
    return out;
  }

  /// Ensures [selection]'s font is registered so the family name resolves to
  /// real glyphs. A no-op for the platform default (empty family).
  Future<void> ensureRegistered(FontSelection selection) async {
    if (selection.family.isEmpty) return;
    switch (selection.source) {
      case FontSource.system:
        await SystemFonts().loadFont(selection.family);
      case FontSource.local:
        if (selection.path.isNotEmpty && File(selection.path).existsSync()) {
          await _registerLocal(selection.family, selection.path);
        }
      case FontSource.google:
        // Download (or load from cache) + register the family and await it so it
        // resolves to real glyphs before the theme rebuilds (otherwise the
        // first apply silently falls back to the platform default).
        try {
          await _ensureGoogleRegistered(selection.family);
        } catch (_) {
          // Unknown Google family or network error — fall back to the default.
        }
    }
  }

  /// User-Agent of an old browser without woff/woff2 support, so the Google
  /// Fonts CSS API serves plain TrueType (`.ttf`) URLs. [FontLoader] can only
  /// register `.ttf`/`.otf`, not the woff2 modern browsers receive.
  static const String _kTtfUserAgent =
      'Mozilla/5.0 (Linux; U; Android 2.2; en-us; Nexus One Build/FRF91) '
      'AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1';

  /// Families already registered this session, to skip redundant work.
  final Set<String> _registeredGoogle = {};

  /// The directory caching downloaded Google Fonts `.ttf` files — one subfolder
  /// per family holding its per-subset slices — so they survive restarts and
  /// re-register without hitting the network again.
  Future<Directory> _googleFontsCacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'google_fonts_cache'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Downloads (if not cached) and registers a Google Fonts [family] under its
  /// own name via [FontLoader] — the HTTP/CSS-API replacement for the dropped
  /// `google_fonts` package. Caches every subset slice under the app documents
  /// folder and feeds them all into a single [FontLoader].
  Future<void> _ensureGoogleRegistered(String family) async {
    if (family.isEmpty || _registeredGoogle.contains(family)) return;
    final cacheDir = await _googleFontsCacheDir();
    final safe = family.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final familyDir = Directory(p.join(cacheDir.path, safe));

    var files = familyDir.existsSync()
        ? familyDir
              .listSync()
              .whereType<File>()
              .where((f) => p.extension(f.path).toLowerCase() == '.ttf')
              .toList()
        : <File>[];
    if (files.isEmpty) {
      files = await _downloadGoogleFont(family, familyDir);
    }
    if (files.isEmpty) return;

    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = await file.readAsBytes();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    _registeredGoogle.add(family);
  }

  /// Fetches the CSS for [family] from the Google Fonts API, extracts every
  /// `.ttf` URL, downloads each slice into [familyDir] and returns the written
  /// files (empty if the family is unknown or the network is unavailable).
  Future<List<File>> _downloadGoogleFont(
    String family,
    Directory familyDir,
  ) async {
    final dio = buildAppDio();
    final cssUrl =
        'https://fonts.googleapis.com/css2'
        '?family=${Uri.encodeQueryComponent(family)}&display=swap';
    final cssResp = await dio.get<String>(
      cssUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {'User-Agent': _kTtfUserAgent},
      ),
    );
    final css = cssResp.data ?? '';
    final urls = RegExp(r'url\((https?://[^)]+\.ttf)\)')
        .allMatches(css)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
    if (urls.isEmpty) return const [];

    if (!familyDir.existsSync()) familyDir.createSync(recursive: true);
    final files = <File>[];
    for (var i = 0; i < urls.length; i++) {
      final resp = await dio.get<List<int>>(
        urls[i],
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) continue;
      final file = File(p.join(familyDir.path, '$i.ttf'));
      await file.writeAsBytes(bytes);
      files.add(file);
    }
    return files;
  }

  Future<void> _registerLocal(String alias, String path) async {
    final bytes = await File(path).readAsBytes();
    final loader = FontLoader(alias)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  /// Lets the user pick a `.ttf` / `.otf` / `.ttc` file, copies it into the app
  /// fonts directory, registers it via [FontLoader] and returns the resulting
  /// [FontSelection] (or `null` if the picker was dismissed).
  Future<FontSelection?> importLocalFont() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf', 'ttc'],
    );
    final picked = result?.files.firstOrNull;
    final srcPath = picked?.path;
    if (srcPath == null) return null;

    final alias = p.basenameWithoutExtension(srcPath);
    final ext = p.extension(srcPath);
    final dir = await _fontsDir();
    final destPath = p.join(dir.path, '$alias$ext');
    await File(srcPath).copy(destPath);
    await _registerLocal(alias, destPath);
    return FontSelection(
      source: FontSource.local,
      family: alias,
      path: destPath,
    );
  }
}

@Riverpod(keepAlive: true)
FontLoaderService fontLoaderService(Ref ref) => FontLoaderService();

/// Holds the 全局字体 configuration (应用字体 + 代码字体), so the appearance page
/// stays a pure view.
///
/// `keepAlive: true`: an app-level preference fed into the active theme and the
/// code blocks, so it must outlive the appearance page. Hydrated from the Drift
/// key/value store on first build — re-registering any persisted system / local
/// / Google font so it is available again after a restart — and written through
/// on every change.
@Riverpod(keepAlive: true)
class FontSettingsController extends _$FontSettingsController {
  ChatRepository get _store => ref.read(appSettingsStoreProvider);

  @override
  FontSettings build() {
    _hydrate();
    return const FontSettings();
  }

  Future<void> _hydrate() async {
    final stored = await _store.getSetting(kFontSettingKey);
    if (stored == null || stored.isEmpty) return;
    try {
      final settings = FontSettings.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
      final service = ref.read(fontLoaderServiceProvider);
      await service.ensureRegistered(settings.appFont);
      await service.ensureRegistered(settings.codeFont);
      state = settings;
    } on FormatException {
      // Corrupt value — keep the defaults.
    }
  }

  /// Sets 应用字体 (UI text). Registers the font first so it resolves immediately.
  Future<void> setAppFont(FontSelection selection) async {
    await ref.read(fontLoaderServiceProvider).ensureRegistered(selection);
    _persist(state.copyWith(appFont: selection));
  }

  /// Sets 代码字体 (code blocks + inline code).
  Future<void> setCodeFont(FontSelection selection) async {
    await ref.read(fontLoaderServiceProvider).ensureRegistered(selection);
    _persist(state.copyWith(codeFont: selection));
  }

  void _persist(FontSettings next) {
    state = next;
    _store.saveSetting(kFontSettingKey, jsonEncode(next.toJson()));
  }
}

/// Resolves a [FontSelection] to the family name Flutter should render with, or
/// `null` for the platform default. Google fonts register under their own
/// family name (via [FontLoaderService.ensureRegistered]), so the family name
/// resolves directly — same as system / local fonts.
String? resolveFontFamily(FontSelection selection) {
  if (selection.family.isEmpty) return null;
  return selection.family;
}

/// The effective 应用字体 family fed into `ThemeData` (`null` = platform default).
@Riverpod(keepAlive: true)
String? appFontFamily(Ref ref) =>
    resolveFontFamily(ref.watch(fontSettingsControllerProvider).appFont);

/// The effective 代码字体 family for code blocks / inline code (`null` lets the
/// caller fall back to the platform monospace face).
@Riverpod(keepAlive: true)
String? codeFontFamily(Ref ref) =>
    resolveFontFamily(ref.watch(fontSettingsControllerProvider).codeFont);
