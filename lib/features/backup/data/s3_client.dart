import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_file_item.dart';

/// S3-compatible storage client with AWS Signature V4 authentication.
/// Supports AWS S3, Cloudflare R2, MinIO, and other S3-compatible providers.
class S3BackupClient {
  const S3BackupClient();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Test connectivity by attempting to read the manifest or list the bucket.
  Future<void> test(S3Config cfg) async {
    _validateConfig(cfg);
    final manifestRes = await _sendSigned(
      cfg,
      method: 'GET',
      uri: _buildObjectUri(cfg, _manifestKey(cfg)),
      headers: {'accept': 'application/json'},
    );
    if (manifestRes.statusCode == 200 || _isMissingObject(manifestRes)) return;

    final prefix = _normalizePrefix(cfg.prefix);
    final res = await _sendSignedBucketList(
      cfg,
      query: {
        'list-type': '2',
        if (prefix.isNotEmpty) 'prefix': prefix,
        'max-keys': '1',
      },
    );
    if (res.statusCode != 200) {
      throw Exception('S3 test failed: ${_extractErrorMessage(manifestRes)}');
    }
  }

  /// Upload a file to S3 using streamed PUT (avoids loading entire file into memory).
  Future<void> uploadFile(
    S3Config cfg, {
    required String key,
    required File file,
  }) async {
    _validateConfig(cfg);
    final uri = _buildObjectUri(cfg, key);
    final streamed = await _sendSignedStreamedFile(
      cfg,
      method: 'PUT',
      uri: uri,
      bodyFile: file,
      headers: {'content-type': 'application/zip'},
    );
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('S3 upload failed: ${_extractErrorMessage(res)}');
    }
    await _upsertManifestItem(
      cfg,
      key: key,
      size: await file.length(),
      lastModified: DateTime.now().toUtc(),
    );
  }

  /// Download an S3 object directly to a local file.
  Future<void> downloadToFile(
    S3Config cfg, {
    required String key,
    required File destination,
  }) async {
    _validateConfig(cfg);
    final uri = _buildObjectUri(cfg, key);
    await _sendSignedDownloadToFile(cfg, uri: uri, destination: destination);
  }

  /// Delete an object from S3.
  Future<void> deleteObject(S3Config cfg, {required String key}) async {
    _validateConfig(cfg);
    final uri = _buildObjectUri(cfg, key);
    final res = await _sendSigned(cfg, method: 'DELETE', uri: uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('S3 delete failed: ${_extractErrorMessage(res)}');
    }
    await _removeManifestItem(cfg, key: key);
  }

  /// List all backup objects (merging manifest with bucket listing).
  Future<List<BackupFileItem>> listObjects(S3Config cfg) async {
    _validateConfig(cfg);
    List<BackupFileItem> manifestItems = const [];
    var manifestExists = false;
    Object? manifestError;
    try {
      final manifest = await _readManifest(cfg);
      if (manifest != null) {
        manifestItems = manifest;
        manifestExists = true;
      }
    } catch (e) {
      manifestError = e;
    }

    List<BackupFileItem> bucketItems = const [];
    Object? bucketError;
    var bucketListSucceeded = false;
    try {
      bucketItems = await _listBucketObjects(cfg);
      bucketListSucceeded = true;
    } catch (e) {
      bucketError = e;
    }

    final merged = _mergeItems(
      manifestItems,
      bucketItems,
      bucketIsAuthoritative: bucketListSucceeded,
    );
    if (bucketListSucceeded) {
      await _writeManifestIfChanged(
        cfg,
        manifestExists: manifestExists,
        currentItems: manifestItems,
        reconciledItems: merged,
      );
      if (merged.isNotEmpty || manifestError == null) return merged;
      throw manifestError;
    }
    if (merged.isNotEmpty) return merged;
    if (manifestError != null) throw manifestError;
    if (bucketError != null) throw bucketError;
    return const [];
  }

  // ---------------------------------------------------------------------------
  // Internal: Configuration
  // ---------------------------------------------------------------------------

  static const String _manifestObjectName = '.aetherlink_backups_manifest.json';

  static void _validateConfig(S3Config cfg) {
    if (cfg.endpoint.trim().isEmpty) throw Exception('S3 endpoint is required');
    if (cfg.region.trim().isEmpty) throw Exception('S3 region is required');
    if (cfg.bucket.trim().isEmpty) throw Exception('S3 bucket is required');
    if (cfg.accessKeyId.trim().isEmpty) {
      throw Exception('S3 accessKeyId is required');
    }
    if (cfg.secretAccessKey.isEmpty) {
      throw Exception('S3 secretAccessKey is required');
    }
  }

  static String _normalizeEndpoint(String endpoint) {
    var s = endpoint.trim();
    if (s.isEmpty) throw Exception('S3 endpoint is empty');
    if (!s.contains('://')) s = 'https://$s';
    return s;
  }

  static String _normalizePrefix(String prefix) {
    var s = prefix.trim().replaceAll(RegExp(r'^/+'), '');
    if (s.isEmpty) return '';
    if (!s.endsWith('/')) s = '$s/';
    return s;
  }

  static String _manifestKey(S3Config cfg) =>
      '${_normalizePrefix(cfg.prefix)}$_manifestObjectName';

  // ---------------------------------------------------------------------------
  // Internal: URI building
  // ---------------------------------------------------------------------------

  static List<String> _normalizedBasePathSegments(Uri base, S3Config cfg) {
    final segs = base.pathSegments.where((s) => s.trim().isNotEmpty).toList();
    final bucket = cfg.bucket.trim();
    if (!cfg.pathStyle || bucket.isEmpty || segs.isEmpty) return segs;
    if (segs.last == bucket) return segs.sublist(0, segs.length - 1);
    return segs;
  }

  static Uri _buildBucketUri(S3Config cfg, {Map<String, String>? query}) {
    final base = Uri.parse(_normalizeEndpoint(cfg.endpoint));
    final baseSegs = _normalizedBasePathSegments(base, cfg);
    final host = cfg.pathStyle ? base.host : '${cfg.bucket}.${base.host}';
    final segs = cfg.pathStyle ? [...baseSegs, cfg.bucket] : [...baseSegs];
    final queryStr =
        (query != null && query.isNotEmpty) ? _canonicalQuery(query) : null;
    return Uri(
      scheme: base.scheme.isEmpty ? 'https' : base.scheme,
      host: host,
      port: base.hasPort ? base.port : null,
      pathSegments: segs,
      query: queryStr,
    );
  }

  static Uri _withTrailingSlash(Uri uri) {
    if (uri.path.isEmpty || uri.path.endsWith('/')) return uri;
    return uri.replace(path: '${uri.path}/');
  }

  static Uri _buildObjectUri(S3Config cfg, String key) {
    final base = Uri.parse(_normalizeEndpoint(cfg.endpoint));
    final baseSegs = _normalizedBasePathSegments(base, cfg);
    final keySegs = key.split('/').where((s) => s.isNotEmpty).toList();
    final host = cfg.pathStyle ? base.host : '${cfg.bucket}.${base.host}';
    final segs = cfg.pathStyle
        ? [...baseSegs, cfg.bucket, ...keySegs]
        : [...baseSegs, ...keySegs];
    return Uri(
      scheme: base.scheme.isEmpty ? 'https' : base.scheme,
      host: host,
      port: base.hasPort ? base.port : null,
      pathSegments: segs,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal: AWS Signature V4
  // ---------------------------------------------------------------------------

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _amzDate(DateTime utc) {
    final t = utc.toUtc();
    return '${t.year}${_two(t.month)}${_two(t.day)}T${_two(t.hour)}${_two(t.minute)}${_two(t.second)}Z';
  }

  static String _dateStamp(DateTime utc) {
    final t = utc.toUtc();
    return '${t.year}${_two(t.month)}${_two(t.day)}';
  }

  static String _hashHex(List<int> bytes) => sha256.convert(bytes).toString();

  static List<int> _hmacSha256(List<int> key, String msg) =>
      Hmac(sha256, key).convert(utf8.encode(msg)).bytes;

  static String _hex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static String _awsEncode(String s) =>
      Uri.encodeComponent(s).replaceAll('%7E', '~');

  static String _canonicalQuery(Map<String, String> query) {
    final pairs = <(String, String)>[
      for (final e in query.entries) (e.key, e.value),
    ];
    pairs.sort((a, b) {
      final k = _awsEncode(a.$1).compareTo(_awsEncode(b.$1));
      if (k != 0) return k;
      return _awsEncode(a.$2).compareTo(_awsEncode(b.$2));
    });
    return pairs.map((p) => '${_awsEncode(p.$1)}=${_awsEncode(p.$2)}').join('&');
  }

  static String _canonicalHeaders(Map<String, String> headers) {
    final entries = headers.entries
        .map((e) => MapEntry(
              e.key.toLowerCase().trim(),
              e.value.trim().replaceAll(RegExp(r'\s+'), ' '),
            ))
        .toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    final sb = StringBuffer();
    for (final e in entries) {
      sb.write('${e.key}:${e.value}\n');
    }
    return sb.toString();
  }

  static String _signedHeaders(Map<String, String> headers) {
    final names =
        headers.keys.map((k) => k.toLowerCase().trim()).toSet().toList()..sort();
    return names.join(';');
  }

  static String _hostHeader(Uri uri) {
    if (!uri.hasPort) return uri.host;
    final port = uri.port;
    if (uri.scheme == 'https' && port == 443) return uri.host;
    if (uri.scheme == 'http' && port == 80) return uri.host;
    return '${uri.host}:$port';
  }

  static String _signature({
    required String secretAccessKey,
    required String dateStamp,
    required String region,
    required String service,
    required String stringToSign,
  }) {
    final kSecret = utf8.encode('AWS4$secretAccessKey');
    final kDate = _hmacSha256(kSecret, dateStamp);
    final kRegion = _hmacSha256(kDate, region);
    final kService = _hmacSha256(kRegion, service);
    final kSigning = _hmacSha256(kService, 'aws4_request');
    final sig = Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).bytes;
    return _hex(sig);
  }

  // ---------------------------------------------------------------------------
  // Internal: HTTP requests with SigV4
  // ---------------------------------------------------------------------------

  static Future<http.Response> _sendSigned(
    S3Config cfg, {
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    List<int>? bodyBytes,
  }) async {
    final now = DateTime.now().toUtc();
    final amzDate = _amzDate(now);
    final dateStamp = _dateStamp(now);
    final payload = bodyBytes ?? const <int>[];
    final payloadHash = _hashHex(payload);
    final query = uri.queryParameters;
    final canonQueryStr = query.isEmpty ? '' : _canonicalQuery(query);

    final host = _hostHeader(uri);
    final reqHeaders = <String, String>{
      'host': host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      ...?headers,
    };
    if (cfg.sessionToken.trim().isNotEmpty) {
      reqHeaders['x-amz-security-token'] = cfg.sessionToken.trim();
    }

    final canonHeaders = _canonicalHeaders(reqHeaders);
    final signedHdrs = _signedHeaders(reqHeaders);
    final canonicalRequest = [
      method,
      uri.path.isEmpty ? '/' : uri.path,
      canonQueryStr,
      canonHeaders,
      signedHdrs,
      payloadHash,
    ].join('\n');
    final canonicalRequestHash = _hashHex(utf8.encode(canonicalRequest));
    final scope = '$dateStamp/${cfg.region.trim()}/s3/aws4_request';
    final sts =
        'AWS4-HMAC-SHA256\n$amzDate\n$scope\n$canonicalRequestHash';
    final sig = _signature(
      secretAccessKey: cfg.secretAccessKey,
      dateStamp: dateStamp,
      region: cfg.region.trim(),
      service: 's3',
      stringToSign: sts,
    );
    final auth =
        'AWS4-HMAC-SHA256 Credential=${cfg.accessKeyId.trim()}/$scope, SignedHeaders=$signedHdrs, Signature=$sig';

    final req = http.Request(method, uri);
    req.headers.addAll({...reqHeaders, 'Authorization': auth});
    if (payload.isNotEmpty) req.bodyBytes = Uint8List.fromList(payload);

    final client = http.Client();
    try {
      final streamed = await client.send(req);
      return await http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }

  static Future<http.StreamedResponse> _sendSignedStreamedFile(
    S3Config cfg, {
    required String method,
    required Uri uri,
    required File bodyFile,
    Map<String, String>? headers,
  }) async {
    final now = DateTime.now().toUtc();
    final amzDate = _amzDate(now);
    final dateStamp = _dateStamp(now);
    const payloadHash = 'UNSIGNED-PAYLOAD';
    final query = uri.queryParameters;
    final canonQueryStr = query.isEmpty ? '' : _canonicalQuery(query);

    final host = _hostHeader(uri);
    final fileLen = await bodyFile.length();
    final reqHeaders = <String, String>{
      'host': host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'content-length': fileLen.toString(),
      ...?headers,
    };
    if (cfg.sessionToken.trim().isNotEmpty) {
      reqHeaders['x-amz-security-token'] = cfg.sessionToken.trim();
    }

    final canonHeaders = _canonicalHeaders(reqHeaders);
    final signedHdrs = _signedHeaders(reqHeaders);
    final canonicalRequest = [
      method,
      uri.path.isEmpty ? '/' : uri.path,
      canonQueryStr,
      canonHeaders,
      signedHdrs,
      payloadHash,
    ].join('\n');
    final canonicalRequestHash = _hashHex(utf8.encode(canonicalRequest));
    final scope = '$dateStamp/${cfg.region.trim()}/s3/aws4_request';
    final sts =
        'AWS4-HMAC-SHA256\n$amzDate\n$scope\n$canonicalRequestHash';
    final sig = _signature(
      secretAccessKey: cfg.secretAccessKey,
      dateStamp: dateStamp,
      region: cfg.region.trim(),
      service: 's3',
      stringToSign: sts,
    );
    final auth =
        'AWS4-HMAC-SHA256 Credential=${cfg.accessKeyId.trim()}/$scope, SignedHeaders=$signedHdrs, Signature=$sig';

    final req = http.StreamedRequest(method, uri);
    req.headers.addAll({...reqHeaders, 'Authorization': auth});
    bodyFile.openRead().listen(
      req.sink.add,
      onDone: req.sink.close,
      onError: req.sink.addError,
    );

    final client = http.Client();
    try {
      return await client.send(req);
    } catch (e) {
      client.close();
      rethrow;
    }
  }

  static Future<void> _sendSignedDownloadToFile(
    S3Config cfg, {
    required Uri uri,
    required File destination,
  }) async {
    final now = DateTime.now().toUtc();
    final amzDate = _amzDate(now);
    final dateStamp = _dateStamp(now);
    final payloadHash = _hashHex(const <int>[]);
    final query = uri.queryParameters;
    final canonQueryStr = query.isEmpty ? '' : _canonicalQuery(query);

    final host = _hostHeader(uri);
    final reqHeaders = <String, String>{
      'host': host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
    };
    if (cfg.sessionToken.trim().isNotEmpty) {
      reqHeaders['x-amz-security-token'] = cfg.sessionToken.trim();
    }

    final canonHeaders = _canonicalHeaders(reqHeaders);
    final signedHdrs = _signedHeaders(reqHeaders);
    final canonicalRequest = [
      'GET',
      uri.path.isEmpty ? '/' : uri.path,
      canonQueryStr,
      canonHeaders,
      signedHdrs,
      payloadHash,
    ].join('\n');
    final canonicalRequestHash = _hashHex(utf8.encode(canonicalRequest));
    final scope = '$dateStamp/${cfg.region.trim()}/s3/aws4_request';
    final sts =
        'AWS4-HMAC-SHA256\n$amzDate\n$scope\n$canonicalRequestHash';
    final sig = _signature(
      secretAccessKey: cfg.secretAccessKey,
      dateStamp: dateStamp,
      region: cfg.region.trim(),
      service: 's3',
      stringToSign: sts,
    );
    final auth =
        'AWS4-HMAC-SHA256 Credential=${cfg.accessKeyId.trim()}/$scope, SignedHeaders=$signedHdrs, Signature=$sig';

    final req = http.Request('GET', uri);
    req.headers.addAll({...reqHeaders, 'Authorization': auth});

    final client = http.Client();
    try {
      final streamed = await client.send(req);
      if (streamed.statusCode != 200) {
        final res = await http.Response.fromStream(streamed);
        throw Exception('S3 download failed: ${_extractErrorMessage(res)}');
      }
      await destination.parent.create(recursive: true);
      final sink = destination.openWrite();
      await streamed.stream.pipe(sink);
    } finally {
      client.close();
    }
  }

  static Future<http.Response> _sendSignedBucketList(
    S3Config cfg, {
    required Map<String, String> query,
  }) async {
    final primary = _buildBucketUri(cfg, query: query);
    final candidates = <Uri>[primary, _withTrailingSlash(primary)];
    final tried = <String>{};
    http.Response? firstFailure;

    for (final uri in candidates) {
      if (!tried.add(uri.toString())) continue;
      final res = await _sendSigned(
        cfg,
        method: 'GET',
        uri: uri,
        headers: {'accept': 'application/xml'},
      );
      if (res.statusCode == 200) return res;
      firstFailure ??= res;
      if (_extractErrorCode(res) != 'NoSuchKey') return res;
    }
    return firstFailure!;
  }

  // ---------------------------------------------------------------------------
  // Internal: Manifest operations
  // ---------------------------------------------------------------------------

  Future<List<BackupFileItem>?> _readManifest(S3Config cfg) async {
    final res = await _sendSigned(
      cfg,
      method: 'GET',
      uri: _buildObjectUri(cfg, _manifestKey(cfg)),
      headers: {'accept': 'application/json'},
    );
    if (_isMissingObject(res)) return null;
    if (res.statusCode != 200) {
      throw Exception('S3 manifest read failed: ${_extractErrorMessage(res)}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('S3 manifest format invalid');
    }
    final rawItems = decoded['items'];
    if (rawItems is! List) {
      throw Exception('S3 manifest items invalid');
    }

    final items = rawItems
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .where((e) {
          final key = (e['key'] as String?)?.trim() ?? '';
          return key.isNotEmpty && key.toLowerCase().endsWith('.zip');
        })
        .map((e) => _itemFromManifestEntry(cfg, e))
        .toList();

    items.sort((a, b) =>
        (b.lastModified ?? DateTime(0)).compareTo(a.lastModified ?? DateTime(0)));
    return items;
  }

  Future<void> _writeManifest(S3Config cfg, List<BackupFileItem> items) async {
    final encoded = utf8.encode(jsonEncode({
      'version': 1,
      'items': items
          .map((item) => {
                'key': _keyFromItem(item),
                'displayName': item.displayName,
                'size': item.size,
                'lastModified': item.lastModified?.toUtc().toIso8601String(),
              })
          .toList(),
    }));
    final res = await _sendSigned(
      cfg,
      method: 'PUT',
      uri: _buildObjectUri(cfg, _manifestKey(cfg)),
      headers: {'content-type': 'application/json'},
      bodyBytes: encoded,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('S3 manifest write failed: ${_extractErrorMessage(res)}');
    }
  }

  Future<void> _upsertManifestItem(
    S3Config cfg, {
    required String key,
    required int size,
    required DateTime lastModified,
  }) async {
    final current = await _readManifest(cfg) ?? <BackupFileItem>[];
    final next = <BackupFileItem>[
      BackupFileItem(
        href: Uri(
          scheme: 's3',
          host: cfg.bucket.trim(),
          pathSegments: key.split('/').where((s) => s.isNotEmpty).toList(),
        ),
        displayName: _displayNameFromKey(key),
        size: size,
        lastModified: lastModified,
      ),
      ...current.where((item) => _keyFromItem(item) != key),
    ];
    await _writeManifest(cfg, next);
  }

  Future<void> _removeManifestItem(S3Config cfg, {required String key}) async {
    final current = await _readManifest(cfg);
    if (current == null) return;
    final next = current.where((item) => _keyFromItem(item) != key).toList();
    await _writeManifest(cfg, next);
  }

  // ---------------------------------------------------------------------------
  // Internal: Bucket listing
  // ---------------------------------------------------------------------------

  Future<List<BackupFileItem>> _listBucketObjects(S3Config cfg) async {
    final prefix = _normalizePrefix(cfg.prefix);
    final items = <BackupFileItem>[];
    String? continuationToken;

    do {
      final res = await _sendSignedBucketList(
        cfg,
        query: {
          'list-type': '2',
          if (prefix.isNotEmpty) 'prefix': prefix,
          'max-keys': '1000',
          if (continuationToken != null) 'continuation-token': continuationToken,
        },
      );
      if (res.statusCode != 200) {
        throw Exception('S3 list failed: ${_extractErrorMessage(res)}');
      }

      final doc = XmlDocument.parse(res.body);
      for (final c in doc.findAllElements('Contents', namespace: '*')) {
        final key = c.getElement('Key', namespace: '*')?.innerText ?? '';
        if (key.trim().isEmpty) continue;
        final sizeStr = c.getElement('Size', namespace: '*')?.innerText ?? '0';
        final mtimeStr =
            c.getElement('LastModified', namespace: '*')?.innerText ?? '';
        final size = int.tryParse(sizeStr.trim()) ?? 0;
        final mtime = _parseDateTime(mtimeStr);
        final name = _displayNameFromKey(key);
        if (!name.toLowerCase().endsWith('.zip')) continue;

        items.add(BackupFileItem(
          href: Uri(
            scheme: 's3',
            host: cfg.bucket.trim(),
            pathSegments: key.split('/').where((s) => s.isNotEmpty).toList(),
          ),
          displayName: name,
          size: size,
          lastModified: mtime,
        ));
      }

      final isTruncated = doc
              .findAllElements('IsTruncated', namespace: '*')
              .map((e) => e.innerText.trim().toLowerCase())
              .firstWhere((s) => s.isNotEmpty, orElse: () => 'false') ==
          'true';
      final nextToken = doc
          .findAllElements('NextContinuationToken', namespace: '*')
          .map((e) => e.innerText.trim())
          .firstWhere((s) => s.isNotEmpty, orElse: () => '');
      continuationToken =
          isTruncated && nextToken.isNotEmpty ? nextToken : null;
    } while (continuationToken != null);

    return items;
  }

  // ---------------------------------------------------------------------------
  // Internal: Merge & reconcile
  // ---------------------------------------------------------------------------

  static List<BackupFileItem> _mergeItems(
    List<BackupFileItem> manifestItems,
    List<BackupFileItem> bucketItems, {
    bool bucketIsAuthoritative = false,
  }) {
    final merged = <String, BackupFileItem>{};

    void upsert(BackupFileItem item) {
      final key = _keyFromItem(item);
      final current = merged[key];
      if (current == null) {
        merged[key] = item;
        return;
      }
      if (current.lastModified == null && item.lastModified != null) {
        merged[key] = item;
        return;
      }
      if (current.lastModified != null &&
          item.lastModified != null &&
          item.lastModified!.isAfter(current.lastModified!)) {
        merged[key] = item;
        return;
      }
      if (current.size == 0 && item.size > 0) merged[key] = item;
    }

    if (!bucketIsAuthoritative) {
      for (final item in manifestItems) {
        upsert(item);
      }
    }
    for (final item in bucketItems) {
      upsert(item);
    }

    final items = merged.values.toList();
    items.sort((a, b) =>
        (b.lastModified ?? DateTime(0)).compareTo(a.lastModified ?? DateTime(0)));
    return items;
  }

  Future<void> _writeManifestIfChanged(
    S3Config cfg, {
    required bool manifestExists,
    required List<BackupFileItem> currentItems,
    required List<BackupFileItem> reconciledItems,
  }) async {
    if (!manifestExists) return;
    if (currentItems.length == reconciledItems.length) {
      var same = true;
      for (var i = 0; i < currentItems.length; i++) {
        if (_keyFromItem(currentItems[i]) != _keyFromItem(reconciledItems[i])) {
          same = false;
          break;
        }
      }
      if (same) return;
    }
    await _writeManifest(cfg, reconciledItems);
  }

  // ---------------------------------------------------------------------------
  // Internal: Utilities
  // ---------------------------------------------------------------------------

  static String _keyFromItem(BackupFileItem item) =>
      item.href.pathSegments.join('/');

  static String _displayNameFromKey(String key) {
    final parts = key.split('/').where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? key : parts.last;
  }

  static DateTime? _parseDateTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static BackupFileItem _itemFromManifestEntry(
    S3Config cfg,
    Map<String, dynamic> entry,
  ) {
    final key = (entry['key'] as String?)?.trim() ?? '';
    final name = (entry['displayName'] as String?)?.trim();
    final sizeValue = entry['size'];
    final size = switch (sizeValue) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()) ?? 0,
      _ => 0,
    };
    final lastModified =
        _parseDateTime((entry['lastModified'] as String?) ?? '');
    return BackupFileItem(
      href: Uri(
        scheme: 's3',
        host: cfg.bucket.trim(),
        pathSegments: key.split('/').where((s) => s.isNotEmpty).toList(),
      ),
      displayName:
          name != null && name.isNotEmpty ? name : _displayNameFromKey(key),
      size: size,
      lastModified: lastModified,
    );
  }

  static bool _isMissingObject(http.Response res) {
    if (res.statusCode == 404) return true;
    return _extractErrorCode(res) == 'NoSuchKey';
  }

  static String _extractErrorMessage(http.Response res) {
    final regionHint = res.headers['x-amz-bucket-region'] ?? '';
    try {
      final doc = XmlDocument.parse(res.body);
      final code = doc
          .findAllElements('Code', namespace: '*')
          .map((e) => e.innerText.trim())
          .firstWhere((s) => s.isNotEmpty, orElse: () => '');
      final msg = doc
          .findAllElements('Message', namespace: '*')
          .map((e) => e.innerText.trim())
          .firstWhere((s) => s.isNotEmpty, orElse: () => '');
      final parts = <String>[
        if (code.isNotEmpty) code,
        if (msg.isNotEmpty) msg,
        if (regionHint.isNotEmpty) 'Bucket region: $regionHint',
      ];
      if (parts.isNotEmpty) return parts.join(' - ');
    } catch (_) {}
    if (regionHint.isNotEmpty) {
      return 'HTTP ${res.statusCode}. Bucket region: $regionHint';
    }
    return 'HTTP ${res.statusCode}';
  }

  static String _extractErrorCode(http.Response res) {
    try {
      final doc = XmlDocument.parse(res.body);
      return doc
          .findAllElements('Code', namespace: '*')
          .map((e) => e.innerText.trim())
          .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    } catch (_) {
      return '';
    }
  }
}
