import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/features/backup/domain/storage_media.dart';

/// 存储空间图片网格的磁盘缩略图缓存：首次显示时在后台缩到 [kThumbWidth]
/// 宽写成 PNG，之后直接读这个小文件——内联 base64 图片不再每次读整条
/// 消息块、解码整张原图。键 = id + 修改时间 + 大小，原图变了自然失效。
class StorageThumbnailCache {
  StorageThumbnailCache._();

  static const int kThumbWidth = 240;

  /// 本地小图直接用原文件，不值得再生成一份。
  static const int _kSmallFileBytes = 256 * 1024;

  /// 缓存目录上限（个数）；超出时删最旧的一半。
  static const int _kMaxEntries = 3000;

  static Future<Directory>? _dir;
  static final Map<String, Future<File?>> _inflight = {};

  /// 缩略图文件；不适用（网络图）或失败时返回 null，调用方回退原图。
  static Future<File?> thumbnailFor(
    StorageMedia item,
    Future<String> Function(String id) loadPayload,
  ) {
    if (!item.isInline && RegExp(r'^https?://').hasMatch(item.source)) {
      return Future.value(null);
    }
    if (!item.isInline && item.bytes > 0 && item.bytes <= _kSmallFileBytes) {
      return Future.value(File(item.source));
    }
    final key = sha1
        .convert(utf8.encode(
            '${item.id}|${item.modifiedAt.millisecondsSinceEpoch}|${item.bytes}'))
        .toString();
    return _inflight[key] ??=
        _build(key, item, loadPayload).whenComplete(() => _inflight.remove(key));
  }

  static Future<Directory> _directory() => _dir ??= () async {
        final dir = Directory(
            p.join((await getApplicationCacheDirectory()).path, 'storage_thumbs'));
        await dir.create(recursive: true);
        _prune(dir);
        return dir;
      }();

  static Future<File?> _build(
    String key,
    StorageMedia item,
    Future<String> Function(String id) loadPayload,
  ) async {
    final dir = await _directory();
    final file = File(p.join(dir.path, '$key.png'));
    if (await file.exists()) return file;

    final Uint8List bytes;
    if (item.isInline) {
      final raw = await loadPayload(item.id);
      bytes = await Isolate.run(() => decodeInlineImage(raw));
    } else {
      bytes = await File(item.source).readAsBytes();
    }
    final png = await _shrink(bytes);
    if (png == null) return null;
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(png);
    await tmp.rename(file.path);
    return file;
  }

  /// 只缩不放：宽度超过 [kThumbWidth] 才缩，按比例算高。
  static Future<Uint8List?> _shrink(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (w, h) => w > kThumbWidth
          ? const ui.TargetImageSize(width: kThumbWidth)
          : ui.TargetImageSize(width: w, height: h),
    );
    try {
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      return data?.buffer.asUint8List();
    } finally {
      codec.dispose();
    }
  }

  static void _prune(Directory dir) {
    try {
      final files = dir.listSync().whereType<File>().toList();
      if (files.length <= _kMaxEntries) return;
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      for (final f in files.take(files.length ~/ 2)) {
        f.deleteSync();
      }
    } catch (_) {}
  }
}

/// 从消息块 JSON 里取内联图片字节（base64Data / file.base64Data / data: URL）。
Uint8List decodeInlineImage(String raw) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final file = data['file'] as Map<String, dynamic>?;
  final source = (data['base64Data'] as String?)?.isNotEmpty == true
      ? data['base64Data'] as String
      : (file?['base64Data'] as String?)?.isNotEmpty == true
          ? file!['base64Data'] as String
          : data['url'] as String? ?? '';
  final encoded =
      source.startsWith('data:') ? source.substring(source.indexOf(',') + 1) : source;
  return base64Decode(encoded.replaceAll(RegExp(r'\s'), ''));
}
