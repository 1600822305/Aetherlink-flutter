import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:system_fonts/system_fonts.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/font_settings.dart';

part 'font_settings_controller.g.dart';

/// Storage key for the persisted 全局字体 settings (a single JSON blob, mirroring
/// how the other appearance settings live under the `settings` slice).
const String kFontSettingKey = 'fontSettings';

/// Loads and registers fonts for the three supported sources, the Flutter-native
/// port of kelivo's font mechanism:
///   * 系统字体 → `system_fonts`（扫描系统字体目录并注册）；
///   * Google Fonts → `google_fonts`（运行时拉取 + 缓存）；
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
  /// Google Fonts picker.
  List<String> googleFonts() => GoogleFonts.asMap().keys.toList()..sort();

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
        // Triggers the background download + registration; the family then
        // resolves on the next frame.
        try {
          GoogleFonts.getFont(selection.family);
        } catch (_) {
          // Unknown Google family — leave it to fall back to the default.
        }
    }
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
/// `null` for the platform default. For Google fonts this also kicks off the
/// background fetch and returns the registered family name.
String? resolveFontFamily(FontSelection selection) {
  if (selection.family.isEmpty) return null;
  if (selection.source == FontSource.google) {
    try {
      return GoogleFonts.getFont(selection.family).fontFamily;
    } catch (_) {
      return null;
    }
  }
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
