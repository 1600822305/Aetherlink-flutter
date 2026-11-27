import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aetherlink_browser/aetherlink_browser.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

/// 书签 / 浏览历史 / 下载：内置浏览器的本地资料库。
/// 持久化到 `<应用支持目录>/browser/library.json`（下载文件本身另存）。
class BrowserLibrary extends ChangeNotifier {
  BrowserLibrary._();

  static final BrowserLibrary instance = BrowserLibrary._();

  static const int _historyCap = 500;

  final List<BrowserBookmark> _bookmarks = [];
  final List<BrowserHistoryEntry> _history = [];
  final List<BrowserDownload> _downloads = [];
  final Map<String, CancelToken> _cancels = {};
  Future<void>? _loading;
  Timer? _saveTimer;
  BrowserSessionManager? _attached;

  List<BrowserBookmark> get bookmarks => List.unmodifiable(_bookmarks);
  List<BrowserHistoryEntry> get history => List.unmodifiable(_history);
  List<BrowserDownload> get downloads => List.unmodifiable(_downloads);

  /// 接到会话管理器：所有会话（用户和智能体）的页面访问记历史，
  /// 下载请求走这里。幂等。
  void attach(BrowserSessionManager manager) {
    if (identical(_attached, manager)) return;
    _attached = manager;
    manager.onPageVisited = (_, url, title) => recordVisit(url, title);
    manager.onDownloadRequested = (_, url, name, mime) =>
        unawaited(download(url, fileName: name, mimeType: mime));
    unawaited(load());
  }

  Future<void> load() => _loading ??= _load();

  Future<File> _file() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/browser');
    await dir.create(recursive: true);
    return File('${dir.path}/library.json');
  }

  Future<void> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map || data['version'] != 1) return;
      _bookmarks
        ..clear()
        ..addAll([
          for (final b in (data['bookmarks'] as List? ?? const []))
            if (b is Map) BrowserBookmark.fromJson(b),
        ]);
      _history
        ..clear()
        ..addAll([
          for (final h in (data['history'] as List? ?? const []))
            if (h is Map) BrowserHistoryEntry.fromJson(h),
        ]);
      _downloads
        ..clear()
        ..addAll([
          for (final d in (data['downloads'] as List? ?? const []))
            if (d is Map) BrowserDownload.fromJson(d),
        ]);
      // 上次没下完的标记为失败（进程已退出，无法续传）。
      for (final d in _downloads) {
        if (d.status == BrowserDownloadStatus.running) {
          d.status = BrowserDownloadStatus.failed;
          d.error = '应用退出时中断';
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _writes = Future<void>.value();

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      final encoded = jsonEncode({
        'version': 1,
        'bookmarks': [for (final b in _bookmarks) b.toJson()],
        'history': [for (final h in _history) h.toJson()],
        'downloads': [for (final d in _downloads) d.toJson()],
      });
      _writes = _writes.then((_) async {
        try {
          final file = await _file();
          final tmp = File('${file.path}.tmp');
          await tmp.writeAsString(encoded, flush: true);
          await tmp.rename(file.path);
        } catch (_) {}
      });
    });
  }

  void _changed() {
    notifyListeners();
    _scheduleSave();
  }

  // ---- 书签 ----

  bool isBookmarked(String url) => _bookmarks.any((b) => b.url == url);

  Future<void> toggleBookmark(String url, String title) async {
    await load();
    final i = _bookmarks.indexWhere((b) => b.url == url);
    if (i >= 0) {
      _bookmarks.removeAt(i);
    } else {
      _bookmarks.insert(
        0,
        BrowserBookmark(url: url, title: title.isEmpty ? url : title),
      );
    }
    _changed();
  }

  Future<void> removeBookmark(String url) async {
    await load();
    _bookmarks.removeWhere((b) => b.url == url);
    _changed();
  }

  // ---- 历史 ----

  Future<void> recordVisit(String url, String title) async {
    if (!url.startsWith('http')) return;
    await load();
    _history.removeWhere((h) => h.url == url);
    _history.insert(
      0,
      BrowserHistoryEntry(url: url, title: title, visitedAt: DateTime.now()),
    );
    if (_history.length > _historyCap) {
      _history.removeRange(_historyCap, _history.length);
    }
    // 书签标题为空时顺手补上。
    for (final b in _bookmarks) {
      if (b.url == url && (b.title.isEmpty || b.title == url) && title.isNotEmpty) {
        b.title = title;
      }
    }
    _changed();
  }

  Future<void> removeHistory(String url) async {
    await load();
    _history.removeWhere((h) => h.url == url);
    _changed();
  }

  Future<void> clearHistory() async {
    await load();
    _history.clear();
    _changed();
  }

  // ---- 下载 ----

  static const _channel = MethodChannel('aetherlink/downloads');

  Future<Directory> _downloadDir() async {
    if (Platform.isAndroid) {
      // Android 先下到缓存，完成后交给系统存入公共「下载/AetherLink」。
      final tmp = Directory(
        '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}browser_dl',
      );
      await tmp.create(recursive: true);
      return tmp;
    }
    Directory? base;
    try {
      base = await getDownloadsDirectory();
    } catch (_) {}
    base ??= await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}AetherLink');
    await dir.create(recursive: true);
    return dir;
  }

  static String _safeName(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim();
    return cleaned.isEmpty ? 'download' : cleaned;
  }

  static String _nameFrom(String url, String? suggested) {
    if (suggested != null && suggested.trim().isNotEmpty) {
      return _safeName(suggested);
    }
    final seg = Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty);
    return _safeName(seg == null || seg.isEmpty ? 'download' : seg.last);
  }

  /// 同名文件存在时追加 (1)、(2)……，从不覆盖。
  static Future<File> _uniqueFile(Directory dir, String name) async {
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    var candidate = File('${dir.path}${Platform.pathSeparator}$name');
    for (var n = 1; await candidate.exists(); n++) {
      candidate = File('${dir.path}${Platform.pathSeparator}$stem ($n)$ext');
    }
    return candidate;
  }

  /// 带上 WebView 的 cookie 和 UA 下载（登录后才能下的文件也能下）。
  Future<void> download(
    String url, {
    String? fileName,
    String? mimeType,
  }) async {
    await load();
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _downloads.insert(
        0,
        BrowserDownload(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          url: url,
          fileName: _nameFrom(url, fileName),
          status: BrowserDownloadStatus.failed,
          error: '不支持的下载地址（${uri?.scheme ?? '无效'}）',
        ),
      );
      _changed();
      return;
    }
    final item = BrowserDownload(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: url,
      fileName: _nameFrom(url, fileName),
      status: BrowserDownloadStatus.running,
    );
    _downloads.insert(0, item);
    _changed();
    final cancel = CancelToken();
    _cancels[item.id] = cancel;
    try {
      // 下载前同样过 SSRF 策略，页面不能借下载访问内网。
      await UrlPolicy().validate(url);
      final dir = await _downloadDir();
      final file = await _uniqueFile(dir, item.fileName);
      item.fileName = file.uri.pathSegments.last;
      item.path = file.path;
      final headers = <String, String>{};
      final cookie = await BrowserWindowsEnvironment.instance.cookieHeaderFor(
        url,
      );
      if (cookie != null) headers['cookie'] = cookie;
      var lastNotify = DateTime.now();
      await Dio().download(
        url,
        file.path,
        cancelToken: cancel,
        options: Options(headers: headers, followRedirects: true),
        onReceiveProgress: (received, total) {
          item.received = received;
          item.total = total > 0 ? total : null;
          final now = DateTime.now();
          if (now.difference(lastNotify).inMilliseconds > 250) {
            lastNotify = now;
            notifyListeners();
          }
        },
      );
      item.mimeType = mimeType;
      if (Platform.isAndroid) await _publishAndroid(item);
      item.status = BrowserDownloadStatus.done;
    } on DioException catch (e) {
      item.status = CancelToken.isCancel(e)
          ? BrowserDownloadStatus.cancelled
          : BrowserDownloadStatus.failed;
      item.error = CancelToken.isCancel(e) ? null : (e.message ?? '$e');
      await _deletePartial(item);
    } on BrowserException catch (e) {
      item.status = BrowserDownloadStatus.failed;
      item.error = e.message;
    } catch (e) {
      item.status = BrowserDownloadStatus.failed;
      item.error = '$e';
      await _deletePartial(item);
    } finally {
      _cancels.remove(item.id);
      _changed();
    }
  }

  /// 把缓存里下完的文件交给系统存进公共下载目录；Android 9 及以下先
  /// 申请存储权限。失败时保留在应用缓存并在条目上注明原因。
  Future<void> _publishAndroid(BrowserDownload item) async {
    final temp = item.path;
    if (temp == null) return;
    Future<Map?> save() async =>
        await _channel.invokeMethod<Map>('save', {
          'source': temp,
          'name': item.fileName,
          'mime': item.mimeType,
        });
    Map? saved;
    try {
      saved = await save();
    } on PlatformException catch (e) {
      if (e.code == 'permission-required' &&
          await Permission.storage.request().isGranted) {
        saved = await save();
      } else {
        item.error = '未能存入系统下载目录（${e.message ?? e.code}），文件仍在应用缓存';
        return;
      }
    }
    if (saved == null) return;
    item.contentUri = saved['uri'] as String?;
    item.fileName = saved['name'] as String? ?? item.fileName;
    item.mimeType = saved['mime'] as String? ?? item.mimeType;
    try {
      await File(temp).delete();
    } catch (_) {}
    item.path = saved['path'] as String?;
  }

  /// 用系统里能处理该类型的应用打开下载好的文件。
  Future<String?> openDownload(BrowserDownload item) async {
    try {
      final uri = item.contentUri;
      if (Platform.isAndroid && uri != null) {
        await _channel.invokeMethod('open', {'uri': uri, 'mime': item.mimeType});
        return null;
      }
      final path = item.path;
      if (path == null || !await File(path).exists()) return '文件已不存在';
      final ok = await launchUrl(Uri.file(path));
      return ok ? null : '没有能打开该文件的应用';
    } on PlatformException catch (e) {
      return e.message ?? e.code;
    }
  }

  Future<void> _deletePartial(BrowserDownload item) async {
    final uri = item.contentUri;
    if (Platform.isAndroid && uri != null) {
      try {
        await _channel.invokeMethod('delete', {'uri': uri});
      } catch (_) {}
      item.contentUri = null;
      item.path = null;
      return;
    }
    final path = item.path;
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    item.path = null;
  }

  void cancelDownload(String id) => _cancels[id]?.cancel();

  /// 从列表移除；[deleteFile] 时连文件一起删。
  Future<void> removeDownload(String id, {bool deleteFile = false}) async {
    final i = _downloads.indexWhere((d) => d.id == id);
    if (i < 0) return;
    final item = _downloads[i];
    _cancels[id]?.cancel();
    if (deleteFile) await _deletePartial(item);
    _downloads.removeAt(i);
    _changed();
  }
}

class BrowserBookmark {
  BrowserBookmark({required this.url, required this.title});

  factory BrowserBookmark.fromJson(Map json) => BrowserBookmark(
    url: json['url'] as String? ?? '',
    title: json['title'] as String? ?? '',
  );

  final String url;
  String title;

  Map<String, Object?> toJson() => {'url': url, 'title': title};
}

class BrowserHistoryEntry {
  BrowserHistoryEntry({
    required this.url,
    required this.title,
    required this.visitedAt,
  });

  factory BrowserHistoryEntry.fromJson(Map json) => BrowserHistoryEntry(
    url: json['url'] as String? ?? '',
    title: json['title'] as String? ?? '',
    visitedAt:
        DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime(2000),
  );

  final String url;
  final String title;
  final DateTime visitedAt;

  Map<String, Object?> toJson() => {
    'url': url,
    'title': title,
    'at': visitedAt.toIso8601String(),
  };
}

enum BrowserDownloadStatus { running, done, failed, cancelled }

class BrowserDownload {
  BrowserDownload({
    required this.id,
    required this.url,
    required this.fileName,
    required this.status,
    this.path,
    this.received = 0,
    this.total,
    this.error,
    this.contentUri,
    this.mimeType,
  });

  factory BrowserDownload.fromJson(Map json) => BrowserDownload(
    id: json['id'] as String? ?? '',
    url: json['url'] as String? ?? '',
    fileName: json['fileName'] as String? ?? 'download',
    status: BrowserDownloadStatus.values.asNameMap()[json['status']] ??
        BrowserDownloadStatus.failed,
    path: json['path'] as String?,
    received: json['received'] as int? ?? 0,
    total: json['total'] as int?,
    error: json['error'] as String?,
    contentUri: json['contentUri'] as String?,
    mimeType: json['mimeType'] as String?,
  );

  final String id;
  final String url;
  String fileName;
  BrowserDownloadStatus status;
  String? path;
  int received;
  int? total;
  String? error;

  /// Android 公共下载目录里的 content:// URI（打开/删除用）。
  String? contentUri;
  String? mimeType;

  double? get progress =>
      total == null || total == 0 ? null : (received / total!).clamp(0, 1);

  Map<String, Object?> toJson() => {
    'id': id,
    'url': url,
    'fileName': fileName,
    'status': status.name,
    'path': path,
    'received': received,
    'total': total,
    'error': error,
    'contentUri': contentUri,
    'mimeType': mimeType,
  };
}
