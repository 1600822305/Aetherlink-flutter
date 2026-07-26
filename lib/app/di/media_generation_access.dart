import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/media_generation_gateway.dart';

part 'media_generation_access.g.dart';

/// App-level composition seam re-exposing chat's [MediaGenerationGateway]
/// (image / video generation provider routing) so tool layers outside `chat`
/// (e.g. `shared/mcp_tools`) can generate images without importing chat's
/// `application` directly — same pattern as `model_access.dart`.
@Riverpod(keepAlive: true)
MediaGenerationGateway appMediaGenerationGateway(Ref ref) =>
    ref.watch(mediaGenerationApiProvider);
