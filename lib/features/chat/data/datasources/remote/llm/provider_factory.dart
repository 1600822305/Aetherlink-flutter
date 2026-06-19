import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/core/network/network_proxy_config.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/adapters/anthropic_adapter.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/adapters/gemini_adapter.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/adapters/openai_compatible_adapter.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/llm_protocol.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway_factory.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:dio/dio.dart';

/// The single entry point for obtaining an [LlmGateway]. Selects the adapter by
/// wire protocol ([protocolForModel]); the rest of the app only sees the port.
///
/// Adding a vendor that speaks an existing protocol is config-only (no new
/// adapter). All adapters share one [Dio] (mechanical plumbing); tests inject a
/// [Dio] whose [Dio.httpClientAdapter] replays recorded bytes.
class LlmProviderFactory implements LlmGatewayFactory {
  LlmProviderFactory({Dio? dio, NetworkProxyConfig? proxy})
    : _dio = dio ?? buildLlmDio(proxy: proxy);

  final Dio _dio;

  @override
  LlmGateway forModel(Model model) {
    switch (protocolForModel(model)) {
      case LlmProtocol.openaiCompatible:
        return OpenAiCompatibleAdapter(_dio);
      case LlmProtocol.anthropic:
        return AnthropicAdapter(_dio);
      case LlmProtocol.gemini:
        return GeminiAdapter(_dio);
    }
  }
}
