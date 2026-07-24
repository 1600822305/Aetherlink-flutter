import 'package:aetherlink_flutter/shared/domain/model.dart';

/// 图像/视频生成的供应商路由端口。application 只依赖本接口；具体的
/// OpenAI 兼容 / Gemini / DashScope / Veo / 硅基流动适配在 data 层实现
/// （`MediaGenerationApi`），由 provider 注入 —— 对照 [LlmGatewayFactory]
/// 的做法。
abstract interface class MediaGenerationGateway {
  /// Whether [model] is treated as video-generation-capable.
  bool isVideoGenerationModel(Model model);

  /// Generates images for [prompt] and returns their URLs (http(s) or
  /// `data:` URLs). Throws on failure with a user-showable message.
  Future<List<String>> generateImages({
    required Model model,
    required String prompt,
  });

  /// Generates a video for [prompt] and returns its playable URL.
  Future<String> generateVideo({required Model model, required String prompt});
}
