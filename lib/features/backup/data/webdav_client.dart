import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_file_item.dart';

/// WebDAV client for backup upload/download/listing/deletion.
class WebDavClient {
  final WebDavConfig config;

  WebDavClient({required this.config});

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Tests the connection by issuing a PROPFIND on the collection.
  /// Throws on failure.
  Future<void> testConnection() async {
    await _ensureCollection();
  }

  /// Ensures the backup directory exists on the server (MKCOL).
  Future<void> ensureCollection() async {
    await _ensureCollection();
  }

  /// Uploads a local file to the WebDAV collection.
  Future<void> upload(File file) async {
    await _ensureCollection();
    final target = _fileUri(p.basename(file.path));
    final fileLen = await file.length();

    final req = http.StreamedRequest('PUT', target);
    req.headers.addAll({
      'content-type': 'application/zip',
      'content-length': fileLen.toString(),
      ..._authHeaders(),
    });

    file.openRead().listen(
      req.sink.add,
      onDone: req.sink.close,
      onError: req.sink.addError,
    );

    final client = http.Client();
    try {
      final res = await client.send(req).then(http.Response.fromStream);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('WebDAV upload failed: HTTP ${res.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// Lists backup files in the remote collection (most recent first).
  Future<List<BackupFileItem>> listFiles() async {
    await _ensureCollection();
    final uri = _collectionUri();
    final req = http.Request('PROPFIND', uri);
    req.headers.addAll({
      'Depth': '1',
      'Content-Type': 'application/xml; charset=utf-8',
      ..._authHeaders(),
    });
    req.body = '<?xml version="1.0" encoding="utf-8" ?>\n'
        '<d:propfind xmlns:d="DAV:">\n'
        '  <d:prop>\n'
        '    <d:displayname/>\n'
        '    <d:getcontentlength/>\n'
        '    <d:getlastmodified/>\n'
        '  </d:prop>\n'
        '</d:propfind>';

    final client = http.Client();
    try {
      final res = await client.send(req).then(http.Response.fromStream);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('WebDAV PROPFIND failed: HTTP ${res.statusCode}');
      }
      return _parsePropfindResponse(res.body, uri);
    } finally {
      client.close();
    }
  }

  /// Downloads a remote backup file to a local temporary file.
  Future<File> download(BackupFileItem item) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', item.href);
      req.headers.addAll(_authHeaders());
      final streamed = await client.send(req);
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        await streamed.stream.drain<void>();
        throw Exception('WebDAV download failed: HTTP ${streamed.statusCode}');
      }
      final tmpDir = await Directory.systemTemp.createTemp('webdav_dl_');
      final file = File(p.join(tmpDir.path, item.displayName));
      final sink = file.openWrite();
      await streamed.stream.pipe(sink);
      return file;
    } finally {
      client.close();
    }
  }

  /// Deletes a remote backup file.
  Future<void> delete(BackupFileItem item) async {
    final req = http.Request('DELETE', item.href);
    req.headers.addAll(_authHeaders());
    final client = http.Client();
    try {
      final res = await client.send(req).then(http.Response.fromStream);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('WebDAV delete failed: HTTP ${res.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Uri _collectionUri() {
    String base = config.url.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    String pathPart = config.path.trim();
    if (pathPart.isNotEmpty) {
      pathPart = '/${pathPart.replaceAll(RegExp(r'^/+'), '')}';
    }
    final full = '$base$pathPart/';
    return Uri.parse(full);
  }

  Uri _fileUri(String childName) {
    final base = _collectionUri().toString();
    final child = childName.replaceAll(RegExp(r'^/+'), '');
    return Uri.parse('$base$child');
  }

  Map<String, String> _authHeaders() {
    if (config.username.trim().isEmpty) return {};
    final token =
        base64Encode(utf8.encode('${config.username}:${config.password}'));
    return {'Authorization': 'Basic $token'};
  }

  Future<void> _ensureCollection() async {
    final uri = _collectionUri();

    // First try PROPFIND to check if it exists.
    final checkReq = http.Request('PROPFIND', uri);
    checkReq.headers.addAll({
      'Depth': '0',
      'Content-Type': 'application/xml; charset=utf-8',
      ..._authHeaders(),
    });
    checkReq.body = '<?xml version="1.0" encoding="utf-8" ?>\n'
        '<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>';

    final client = http.Client();
    try {
      final res = await client.send(checkReq).then(http.Response.fromStream);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return; // Collection exists.
      }

      // Try MKCOL to create it.
      final mkcolReq = http.Request('MKCOL', uri);
      mkcolReq.headers.addAll(_authHeaders());
      final mkcolRes =
          await client.send(mkcolReq).then(http.Response.fromStream);
      if (mkcolRes.statusCode < 200 || mkcolRes.statusCode >= 300) {
        // 405 Method Not Allowed often means it already exists.
        if (mkcolRes.statusCode != 405) {
          throw Exception(
            'WebDAV MKCOL failed: HTTP ${mkcolRes.statusCode}',
          );
        }
      }
    } finally {
      client.close();
    }
  }

  List<BackupFileItem> _parsePropfindResponse(String body, Uri baseUri) {
    final doc = XmlDocument.parse(body);
    final items = <BackupFileItem>[];
    final baseStr = baseUri.toString();

    for (final resp in doc.findAllElements('response', namespace: '*')) {
      final href = resp.getElement('href', namespace: '*')?.innerText ?? '';
      if (href.isEmpty) continue;

      final abs = Uri.parse(href).isAbsolute
          ? Uri.parse(href).toString()
          : baseUri.resolve(href).toString();
      // Skip the collection itself.
      if (abs == baseStr) continue;
      // Skip directories.
      if (abs.endsWith('/')) continue;

      final disp = resp
          .findAllElements('displayname', namespace: '*')
          .map((e) => e.innerText)
          .toList();
      final sizeStr = resp
          .findAllElements('getcontentlength', namespace: '*')
          .map((e) => e.innerText)
          .toList();
      final mtimeStr = resp
          .findAllElements('getlastmodified', namespace: '*')
          .map((e) => e.innerText)
          .toList();

      final size = sizeStr.isNotEmpty ? int.tryParse(sizeStr.first) ?? 0 : 0;
      DateTime? mtime;
      if (mtimeStr.isNotEmpty) {
        try {
          mtime = HttpDate.parse(mtimeStr.first);
        } catch (_) {
          try {
            mtime = DateTime.parse(mtimeStr.first);
          } catch (_) {}
        }
      }

      final name = (disp.isNotEmpty && disp.first.trim().isNotEmpty)
          ? disp.first.trim()
          : Uri.parse(href).pathSegments.last;

      // Try to extract timestamp from filename if mtime is missing.
      if (mtime == null) {
        final match = RegExp(
          r'aetherlink_backup_(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2})',
        ).firstMatch(name);
        if (match != null) {
          try {
            final timestamp = match.group(1)!.replaceAll(
                  RegExp(r'T(\d{2})-(\d{2})-(\d{2})'),
                  r'T$1:$2:$3',
                );
            mtime = DateTime.parse(timestamp);
          } catch (_) {}
        }
      }

      items.add(BackupFileItem(
        href: Uri.parse(abs),
        displayName: name,
        size: size,
        lastModified: mtime,
      ));
    }

    items.sort((a, b) => (b.lastModified ?? DateTime(0))
        .compareTo(a.lastModified ?? DateTime(0)));
    return items;
  }
}
