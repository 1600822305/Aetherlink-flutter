import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';

/// Selects the [LlmGateway] for a [Model] by its wire protocol.
///
/// The `application` layer depends on this port, not the concrete
/// `LlmProviderFactory` in `data`, so the controller stays implementation-free
/// and tests inject a fake factory (and a fake gateway) without a network or a
/// real key. The runtime implementation lives in `data` and is wired in via
/// Riverpod (see `chat_providers.dart`).
abstract interface class LlmGatewayFactory {
  LlmGateway forModel(Model model);
}
