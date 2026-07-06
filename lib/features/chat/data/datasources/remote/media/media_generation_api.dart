import 'dart:async';

import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/llm_protocol.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_type.dart';
import 'package:aetherlink_flutter/shared/utils/api_host.dart';
import 'package:dio/dio.dart';

/// 图像/视频生成的供应商适配层，与 web 版的路由完全对齐：
///
/// - 图像（`imageGeneration.ts`）：Gemini 通道走 `models/{id}:generateContent` 的
///   `responseModalities: [TEXT, IMAGE]`（inlineData 转 data URL）；DashScope 的
///   qwen-image 系列走百炼原生多模态生成接口；其余一律走 OpenAI 兼容的
///   `/images/generations`（Grok 请求 b64_json，其余请求 url）。
/// - 视频（`useVideoGeneration.ts`）：Google/Veo 走 `predictLongRunning` 提交 +
///   operation 轮询；其余走硅基流动风格的 `/video/submit` + `/video/status` 轮询。
///
/// 返回值是可直接放进 IMAGE/VIDEO 块 `url` 字段的地址（http(s) 或 data URL）。
class MediaGenerationApi {
  MediaGenerationApi(this._dio);

  final Dio _dio;

  static const _pollInterval = Duration(seconds: 10);
  static const _maxPollAttempts = 60;

  /// Whether [model] should take the DashScope 原生文生图 route (the web's
  /// `isDashScopeImageModel`).
  static bool isDashScopeImageModel(Model model) {
    final key = (model.providerType ?? model.provider).toLowerCase();
    return key == 'dashscope' && model.id.toLowerCase().contains('qwen-image');
  }

  /// Whether [model] is treated as video-generation-capable (the web's
  /// `isVideoModel` check in `useVideoGeneration`).
  static bool isVideoGenerationModel(Model model) {
    if (model.modelTypes?.contains(ModelType.videoGen) ?? false) return true;
    if (model.videoGeneration ?? false) return true;
    if (model.capabilities?.videoGeneration ?? false) return true;
    final id = model.id;
    return id.contains('HunyuanVideo') ||
        id.contains('Wan-AI/Wan2.1-T2V') ||
        id.contains('Wan-AI/Wan2.1-I2V') ||
        id.toLowerCase().contains('video') ||
        id.toLowerCase().startsWith('veo');
  }

  /// Whether the Google Veo route applies (the web checks
  /// `id === 'veo-2.0-generate-001' || provider === 'google'`).
  static bool isVeoModel(Model model) =>
      model.id.toLowerCase().startsWith('veo') ||
      protocolForModel(model) == LlmProtocol.gemini;

  // ---------------------------------------------------------------- images

  /// Generates images for [prompt] and returns their URLs (http(s) or
  /// `data:` URLs). Throws on failure with a user-showable message.
  Future<List<String>> generateImages({
    required Model model,
    required String prompt,
  }) {
    if (protocolForModel(model) == LlmProtocol.gemini) {
      return _geminiImages(model: model, prompt: prompt);
    }
    if (isDashScopeImageModel(model)) {
      return _dashScopeImages(model: model, prompt: prompt);
    }
    return _openAiImages(model: model, prompt: prompt);
  }

  /// Gemini 图像生成：`generateContent` + `responseModalities: [TEXT, IMAGE]`，
  /// 响应里的 `inlineData` 转成 data URL（对齐 `gemini-aisdk/image.ts`）。
  Future<List<String>> _geminiImages({
    required Model model,
    required String prompt,
  }) async {
    final base = _geminiBase(model.baseUrl);
    final response = await _dio.post<Map<String, dynamic>>(
      '$base/models/${model.id}:generateContent',
      options: Options(
        headers: <String, dynamic>{
          'x-goog-api-key': model.apiKey ?? '',
          'Content-Type': 'application/json',
        },
      ),
      data: <String, dynamic>{
        'contents': <Map<String, dynamic>>[
          <String, dynamic>{
            'parts': <Map<String, dynamic>>[
              <String, dynamic>{'text': prompt},
            ],
          },
        ],
        'generationConfig': <String, dynamic>{
          'responseModalities': <String>['TEXT', 'IMAGE'],
        },
      },
    );

    final urls = <String>[];
    final candidates = response.data?['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final content = (candidates.first as Map<String, dynamic>)['content'];
      final parts = content is Map<String, dynamic> ? content['parts'] : null;
      if (parts is List) {
        for (final part in parts) {
          if (part is! Map<String, dynamic>) continue;
          final inline = part['inlineData'] ?? part['inline_data'];
          if (inline is! Map<String, dynamic>) continue;
          final data = inline['data'];
          if (data is! String || data.isEmpty) continue;
          final mime = inline['mimeType'] ?? inline['mime_type'] ?? 'image/png';
          urls.add('data:$mime;base64,$data');
        }
      }
    }
    if (urls.isEmpty) {
      throw StateError('Gemini 没有返回图像数据');
    }
    return urls;
  }

  /// DashScope（阿里云百炼）qwen-image 原生文生图（对齐 `dashscope/image.ts`）。
  Future<List<String>> _dashScopeImages({
    required Model model,
    required String prompt,
  }) async {
    final base = _dashScopeBase(model.baseUrl);
    final response = await _dio.post<Map<String, dynamic>>(
      '$base/api/v1/services/aigc/multimodal-generation/generation',
      options: Options(
        headers: <String, dynamic>{
          'Authorization': 'Bearer ${model.apiKey ?? ''}',
          'Content-Type': 'application/json',
        },
      ),
      data: <String, dynamic>{
        'model': model.id,
        'input': <String, dynamic>{
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{
              'role': 'user',
              'content': <Map<String, dynamic>>[
                <String, dynamic>{'text': prompt},
              ],
            },
          ],
        },
        'parameters': <String, dynamic>{'n': 1},
      },
    );

    final urls = <String>[];
    final output = response.data?['output'];
    final choices = output is Map<String, dynamic> ? output['choices'] : null;
    if (choices is List) {
      for (final choice in choices) {
        if (choice is! Map<String, dynamic>) continue;
        final message = choice['message'];
        final content = message is Map<String, dynamic>
            ? message['content']
            : null;
        if (content is! List) continue;
        for (final item in content) {
          if (item is Map<String, dynamic>) {
            final image = item['image'];
            if (image is String && image.isNotEmpty) urls.add(image);
          }
        }
      }
    }
    if (urls.isEmpty) {
      throw StateError('DashScope 没有返回图像数据');
    }
    return urls;
  }

  /// OpenAI 兼容 `/images/generations`（对齐 `openai/image.ts`：Grok 请求
  /// b64_json、Qwen-Image 用 `image_size`、其余用 `size`）。
  Future<List<String>> _openAiImages({
    required Model model,
    required String prompt,
  }) async {
    final id = model.id.toLowerCase();
    final isGrok = id.contains('grok');
    final isQwenImage = id.contains('qwen-image');
    final body = <String, dynamic>{
      'model': model.id,
      'prompt': prompt,
      'response_format': isGrok ? 'b64_json' : 'url',
      if (!isGrok && isQwenImage) 'image_size': '1328x1328',
      if (!isGrok && !isQwenImage) 'size': '1024x1024',
      if (!isGrok) 'n': 1,
    };
    final response = await _dio.post<Map<String, dynamic>>(
      '${formatApiHost(model.baseUrl)}/images/generations',
      options: Options(
        headers: <String, dynamic>{
          'Authorization': 'Bearer ${model.apiKey ?? ''}',
          'Content-Type': 'application/json',
        },
      ),
      data: body,
    );

    final urls = <String>[];
    final data = response.data?['data'];
    if (data is List) {
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final b64 = item['b64_json'];
        if (b64 is String && b64.isNotEmpty) {
          urls.add('data:image/png;base64,$b64');
          continue;
        }
        final url = item['url'];
        if (url is String && url.isNotEmpty) urls.add(url);
      }
    }
    if (urls.isEmpty) {
      throw StateError('图像生成 API 没有返回有效的图像 URL');
    }
    return urls;
  }

  // ---------------------------------------------------------------- video

  /// Generates a video for [prompt] and returns its playable URL. Long-running:
  /// submits the job then polls every 10s (up to 10 minutes), like the web.
  Future<String> generateVideo({required Model model, required String prompt}) {
    if (isVeoModel(model)) {
      return _veoVideo(model: model, prompt: prompt);
    }
    return _siliconFlowVideo(model: model, prompt: prompt);
  }

  /// Google Veo：`models/{id}:predictLongRunning` 提交，轮询 operation 直到
  /// done，取 `generateVideoResponse.generatedSamples[0].video.uri`（访问需带
  /// key，对齐 `gemini-aisdk/veo.ts`）。
  Future<String> _veoVideo({
    required Model model,
    required String prompt,
  }) async {
    final apiKey = model.apiKey ?? '';
    if (apiKey.isEmpty) {
      throw StateError('Google API 密钥未设置');
    }
    final base = _geminiBase(model.baseUrl);
    final modelId = model.id.toLowerCase().startsWith('veo')
        ? model.id
        : 'veo-2.0-generate-001';
    final submit = await _dio.post<Map<String, dynamic>>(
      '$base/models/$modelId:predictLongRunning',
      options: Options(
        headers: <String, dynamic>{
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        },
      ),
      data: <String, dynamic>{
        'instances': <Map<String, dynamic>>[
          <String, dynamic>{'prompt': prompt},
        ],
        'parameters': <String, dynamic>{
          'aspectRatio': '16:9',
          'personGeneration': 'dont_allow',
        },
      },
    );
    final operationName = submit.data?['name'];
    if (operationName is! String || operationName.isEmpty) {
      throw StateError('Google Veo API 未返回操作名称');
    }

    for (var attempt = 1; attempt <= _maxPollAttempts; attempt++) {
      await Future<void>.delayed(_pollInterval);
      final poll = await _dio.get<Map<String, dynamic>>(
        '$base/$operationName',
        options: Options(headers: <String, dynamic>{'x-goog-api-key': apiKey}),
      );
      final operation = poll.data ?? const <String, dynamic>{};
      if (operation['done'] != true) continue;

      final error = operation['error'];
      if (error is Map<String, dynamic>) {
        throw StateError('Google Veo 生成失败: ${error['message'] ?? error}');
      }
      final response = operation['response'];
      final videoResponse = response is Map<String, dynamic>
          ? response['generateVideoResponse']
          : null;
      final samples = videoResponse is Map<String, dynamic>
          ? videoResponse['generatedSamples']
          : null;
      final first = samples is List && samples.isNotEmpty
          ? samples.first
          : null;
      final video = first is Map<String, dynamic> ? first['video'] : null;
      final uri = video is Map<String, dynamic> ? video['uri'] : null;
      if (uri is! String || uri.isEmpty) {
        throw StateError('Google Veo 生成完成但未返回视频 URL');
      }
      if (uri.contains('key=')) return uri;
      final separator = uri.contains('?') ? '&' : '?';
      return '$uri${separator}key=$apiKey';
    }
    throw StateError('Google Veo 视频生成超时，请稍后重试');
  }

  /// 硅基流动风格：POST `/video/submit` 拿 requestId，POST `/video/status`
  /// 轮询直到 Succeed/completed（对齐 `openai/video.ts`）。
  Future<String> _siliconFlowVideo({
    required Model model,
    required String prompt,
  }) async {
    final base = formatApiHost(model.baseUrl);
    final headers = <String, dynamic>{
      'Authorization': 'Bearer ${model.apiKey ?? ''}',
      'Content-Type': 'application/json',
    };
    final submit = await _dio.post<Map<String, dynamic>>(
      '$base/video/submit',
      options: Options(headers: headers),
      data: <String, dynamic>{'model': model.id, 'prompt': prompt},
    );
    final requestId = submit.data?['requestId'];
    if (requestId is! String || requestId.isEmpty) {
      throw StateError('视频生成请求失败: 未返回 requestId');
    }

    for (var attempt = 1; attempt <= _maxPollAttempts; attempt++) {
      await Future<void>.delayed(_pollInterval);
      final Map<String, dynamic> result;
      try {
        final poll = await _dio.post<Map<String, dynamic>>(
          '$base/video/status',
          options: Options(headers: headers),
          data: <String, dynamic>{'requestId': requestId},
        );
        result = poll.data ?? const <String, dynamic>{};
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;
        // 4xx 直接失败；5xx 继续重试（对齐 web 的轮询容错）。
        if (status >= 400 && status < 500) rethrow;
        continue;
      }

      final status = (result['status'] ?? '').toString();
      switch (status) {
        case 'completed':
        case 'Succeed':
          final url = _extractSiliconFlowVideoUrl(result);
          if (url == null) {
            throw StateError('视频生成完成但未返回视频 URL');
          }
          return url;
        case 'failed':
          throw StateError('视频生成失败: ${result['error'] ?? '未知错误'}');
        default:
          continue; // pending / processing / InQueue / 未知状态：继续轮询。
      }
    }
    throw StateError('视频生成超时，请稍后重试');
  }

  static String? _extractSiliconFlowVideoUrl(Map<String, dynamic> result) {
    final results = result['results'];
    final videos = results is Map<String, dynamic> ? results['videos'] : null;
    if (videos is List && videos.isNotEmpty) {
      final first = videos.first;
      if (first is Map<String, dynamic>) {
        final url = first['url'];
        if (url is String && url.isNotEmpty) return url;
      }
    }
    final videoUrl = result['video_url'];
    if (videoUrl is String && videoUrl.isNotEmpty) return videoUrl;
    final flat = result['videos'];
    if (flat is List && flat.isNotEmpty && flat.first is String) {
      return flat.first as String;
    }
    return null;
  }

  // ---------------------------------------------------------------- hosts

  static String _geminiBase(String? baseUrl) =>
      (baseUrl == null || baseUrl.isEmpty)
      ? 'https://generativelanguage.googleapis.com/v1beta'
      : baseUrl.replaceAll(RegExp(r'/+$'), '');

  /// DashScope 原生接口的主机：从 OpenAI 兼容 baseUrl 推回原生域名，国际站
  /// baseUrl 映射到国际站原生域名（对齐 `dashscope/client.ts`）。
  static String _dashScopeBase(String? baseUrl) {
    final url = baseUrl ?? '';
    if (url.contains('dashscope-intl')) {
      return 'https://dashscope-intl.aliyuncs.com';
    }
    return 'https://dashscope.aliyuncs.com';
  }
}
