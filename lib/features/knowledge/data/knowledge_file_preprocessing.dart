import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_file_processor.dart';

/// 云端文件预处理实现（设计文档 §5.2 云端预处理轨）：把 PDF / DOCX 等富文档
/// 上传到所选服务解析为 Markdown。协议参考 Cherry Studio v2 的
/// fileProcessing processors（MinerU / Doc2X 为「上传 → 轮询 → 下载结果 zip」，
/// Mistral OCR 为同步接口）。任何一步失败都抛 [KnowledgePreprocessException]。
class KnowledgePreprocessException implements Exception {
  KnowledgePreprocessException(this.message);

  final String message;

  @override
  String toString() => 'KnowledgePreprocessException: $message';
}

/// 轮询节奏：间隔 3s，最长约 6 分钟（大文档解析可能较慢）。
const _pollInterval = Duration(seconds: 3);
const _maxPollAttempts = 120;

/// 云端解析入口：按 [processor] 分派到对应服务，返回解析出的 Markdown。
Future<String> preprocessFileInCloud({
  required Dio dio,
  required KnowledgeFileProcessor processor,
  required String apiKey,
  required String fileName,
  required Uint8List bytes,
}) {
  switch (processor) {
    case KnowledgeFileProcessor.mineru:
      return _mineruToMarkdown(dio, apiKey, fileName, bytes);
    case KnowledgeFileProcessor.doc2x:
      return _doc2xToMarkdown(dio, apiKey, fileName, bytes);
    case KnowledgeFileProcessor.mistral:
      return _mistralToMarkdown(dio, apiKey, fileName, bytes);
  }
}

// ── MinerU（https://mineru.net，api/v4 批量接口）──

Future<String> _mineruToMarkdown(
  Dio dio,
  String apiKey,
  String fileName,
  Uint8List bytes,
) async {
  const host = 'https://mineru.net';
  final auth = Options(
    headers: {'Authorization': 'Bearer $apiKey'},
  );

  // 1. 申请上传 URL（batch）。
  final createRes = await dio.post<Map<String, dynamic>>(
    '$host/api/v4/file-urls/batch',
    data: {
      'files': [
        {'name': fileName},
      ],
    },
    options: auth,
  );
  final createData = _requireMineruData(createRes.data, '申请上传 URL');
  final batchId = createData['batch_id'] as String?;
  final fileUrls = createData['file_urls'] as List?;
  if (batchId == null || fileUrls == null || fileUrls.isEmpty) {
    throw KnowledgePreprocessException('MinerU 未返回上传地址');
  }
  final headersList = createData['headers'] as List?;
  final uploadHeaders =
      ((headersList != null && headersList.isNotEmpty)
              ? headersList.first as Map?
              : null)
          ?.cast<String, dynamic>();

  // 2. PUT 原始字节到上传地址（预签名 URL，不带 Authorization）。
  await dio.put<void>(
    fileUrls.first as String,
    data: Stream.fromIterable([bytes]),
    options: Options(
      headers: {
        Headers.contentLengthHeader: bytes.length,
        ...?uploadHeaders,
      },
    ),
  );

  // 3. 轮询批量解析结果直到 done，拿 full_zip_url。
  for (var attempt = 0; attempt < _maxPollAttempts; attempt++) {
    await Future<void>.delayed(_pollInterval);
    final pollRes = await dio.get<Map<String, dynamic>>(
      '$host/api/v4/extract-results/batch/$batchId',
      options: auth,
    );
    final pollData = _requireMineruData(pollRes.data, '查询解析结果');
    final results = pollData['extract_result'] as List?;
    final result = ((results != null && results.isNotEmpty)
            ? results.first as Map?
            : null)
        ?.cast<String, dynamic>();
    if (result == null) continue;
    final state = result['state'] as String?;
    if (state == 'failed') {
      throw KnowledgePreprocessException(
        'MinerU 解析失败: ${result['err_msg'] ?? '未知错误'}',
      );
    }
    if (state == 'done') {
      final zipUrl = result['full_zip_url'] as String?;
      if (zipUrl == null || zipUrl.isEmpty) {
        throw KnowledgePreprocessException('MinerU 完成但未返回结果包地址');
      }
      // 4. 下载结果 zip，取其中的 full.md。
      return _markdownFromZipUrl(dio, zipUrl, serviceName: 'MinerU');
    }
  }
  throw KnowledgePreprocessException('MinerU 解析超时，请稍后重试');
}

Map<String, dynamic> _requireMineruData(Map<String, dynamic>? body, String op) {
  if (body == null) {
    throw KnowledgePreprocessException('MinerU $op 无响应');
  }
  if (body['code'] != 0) {
    throw KnowledgePreprocessException(
      'MinerU $op 失败: ${body['msg'] ?? body['code']}',
    );
  }
  final data = body['data'];
  if (data is! Map) {
    throw KnowledgePreprocessException('MinerU $op 响应缺少 data');
  }
  return data.cast<String, dynamic>();
}

// ── Doc2X（https://v2.doc2x.noedgeai.com，api/v2 预上传 + 导出接口）──

Future<String> _doc2xToMarkdown(
  Dio dio,
  String apiKey,
  String fileName,
  Uint8List bytes,
) async {
  const host = 'https://v2.doc2x.noedgeai.com';
  final auth = Options(
    headers: {'Authorization': 'Bearer $apiKey'},
  );

  // 1. 预上传拿 uid + 上传地址。
  final preRes = await dio.post<Map<String, dynamic>>(
    '$host/api/v2/parse/preupload',
    data: const <String, dynamic>{},
    options: auth,
  );
  final preData = _requireDoc2xData(preRes.data, '预上传');
  final uid = preData['uid'] as String?;
  final uploadUrl = preData['url'] as String?;
  if (uid == null || uploadUrl == null) {
    throw KnowledgePreprocessException('Doc2X 未返回上传地址');
  }

  // 2. PUT 原始字节（预签名 URL，不带 Authorization）。
  await dio.put<void>(
    uploadUrl,
    data: Stream.fromIterable([bytes]),
    options: Options(headers: {Headers.contentLengthHeader: bytes.length}),
  );

  // 3. 轮询解析状态直到 success。
  var parsed = false;
  for (var attempt = 0; attempt < _maxPollAttempts; attempt++) {
    await Future<void>.delayed(_pollInterval);
    final statusRes = await dio.get<Map<String, dynamic>>(
      '$host/api/v2/parse/status',
      queryParameters: {'uid': uid},
      options: auth,
    );
    final status = _requireDoc2xData(statusRes.data, '查询解析状态');
    final state = status['status'] as String?;
    if (state == 'failed') {
      throw KnowledgePreprocessException(
        'Doc2X 解析失败: ${status['detail'] ?? '未知错误'}',
      );
    }
    if (state == 'success') {
      parsed = true;
      break;
    }
  }
  if (!parsed) {
    throw KnowledgePreprocessException('Doc2X 解析超时，请稍后重试');
  }

  // 4. 触发 Markdown 导出，再轮询导出结果拿下载地址（zip）。
  final exportRes = await dio.post<Map<String, dynamic>>(
    '$host/api/v2/convert/parse',
    data: {'uid': uid, 'to': 'md', 'formula_mode': 'normal'},
    options: auth,
  );
  _requireDoc2xData(exportRes.data, '触发导出');
  for (var attempt = 0; attempt < _maxPollAttempts; attempt++) {
    await Future<void>.delayed(_pollInterval);
    final resultRes = await dio.get<Map<String, dynamic>>(
      '$host/api/v2/convert/parse/result',
      queryParameters: {'uid': uid},
      options: auth,
    );
    final result = _requireDoc2xData(resultRes.data, '查询导出结果');
    final state = result['status'] as String?;
    if (state == 'failed') {
      throw KnowledgePreprocessException('Doc2X 导出 Markdown 失败');
    }
    final url = result['url'] as String?;
    if (state == 'success' && url != null && url.isNotEmpty) {
      return _markdownFromZipUrl(dio, url, serviceName: 'Doc2X');
    }
  }
  throw KnowledgePreprocessException('Doc2X 导出超时，请稍后重试');
}

Map<String, dynamic> _requireDoc2xData(Map<String, dynamic>? body, String op) {
  if (body == null) {
    throw KnowledgePreprocessException('Doc2X $op 无响应');
  }
  if (body['code'] != 'success') {
    throw KnowledgePreprocessException(
      'Doc2X $op 失败: ${body['msg'] ?? body['message'] ?? body['code']}',
    );
  }
  final data = body['data'];
  if (data is! Map) {
    throw KnowledgePreprocessException('Doc2X $op 响应缺少 data');
  }
  return data.cast<String, dynamic>();
}

// ── Mistral OCR（https://api.mistral.ai，files + /v1/ocr）──

Future<String> _mistralToMarkdown(
  Dio dio,
  String apiKey,
  String fileName,
  Uint8List bytes,
) async {
  const host = 'https://api.mistral.ai';
  final auth = Options(
    headers: {'Authorization': 'Bearer $apiKey'},
  );

  // 1. 上传文件（purpose=ocr）。
  final uploadRes = await dio.post<Map<String, dynamic>>(
    '$host/v1/files',
    data: FormData.fromMap({
      'purpose': 'ocr',
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    }),
    options: auth,
  );
  final fileId = uploadRes.data?['id'] as String?;
  if (fileId == null) {
    throw KnowledgePreprocessException('Mistral 文件上传未返回 id');
  }

  try {
    // 2. 拿签名下载地址，交给 OCR 接口按页转 Markdown。
    final urlRes = await dio.get<Map<String, dynamic>>(
      '$host/v1/files/$fileId/url',
      queryParameters: {'expiry': 24},
      options: auth,
    );
    final signedUrl = urlRes.data?['url'] as String?;
    if (signedUrl == null) {
      throw KnowledgePreprocessException('Mistral 未返回签名下载地址');
    }

    final ocrRes = await dio.post<Map<String, dynamic>>(
      '$host/v1/ocr',
      data: {
        'model': 'mistral-ocr-latest',
        'document': {'type': 'document_url', 'document_url': signedUrl},
        'include_image_base64': false,
      },
      options: auth,
    );
    final pages = ocrRes.data?['pages'] as List?;
    if (pages == null) {
      throw KnowledgePreprocessException('Mistral OCR 响应缺少 pages');
    }
    final markdown = [
      for (final page in pages)
        if (page is Map && page['markdown'] is String)
          (page['markdown'] as String).trim(),
    ].where((p) => p.isNotEmpty).join('\n\n').trim();
    if (markdown.isEmpty) {
      throw KnowledgePreprocessException('Mistral OCR 返回内容为空');
    }
    return markdown;
  } finally {
    // best-effort 清理已上传文件，失败不影响结果。
    try {
      await dio.delete<void>('$host/v1/files/$fileId', options: auth);
    } catch (_) {}
  }
}

// ── 结果 zip → Markdown ──

/// 下载结果 zip 并取其中的 Markdown（MinerU 固定叫 full.md，Doc2X 为唯一的
/// .md 文件）。找不到 Markdown 视为坏结果抛错。
Future<String> _markdownFromZipUrl(
  Dio dio,
  String zipUrl, {
  required String serviceName,
}) async {
  final zipRes = await dio.get<List<int>>(
    zipUrl,
    options: Options(responseType: ResponseType.bytes),
  );
  final zipBytes = zipRes.data;
  if (zipBytes == null || zipBytes.isEmpty) {
    throw KnowledgePreprocessException('$serviceName 结果包下载失败');
  }
  final archive = ZipDecoder().decodeBytes(zipBytes);
  ArchiveFile? markdownFile;
  for (final file in archive.files) {
    if (!file.isFile) continue;
    final name = file.name.toLowerCase();
    if (!name.endsWith('.md')) continue;
    // 优先 full.md（MinerU 的完整全文），否则取第一个 .md。
    if (name == 'full.md' || name.endsWith('/full.md')) {
      markdownFile = file;
      break;
    }
    markdownFile ??= file;
  }
  if (markdownFile == null) {
    throw KnowledgePreprocessException('$serviceName 结果包里没有 Markdown 文件');
  }
  return utf8.decode(markdownFile.content as List<int>, allowMalformed: true);
}
