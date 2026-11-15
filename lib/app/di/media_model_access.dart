import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/media_model_controller.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Media-generation model access seam: chat must not import settings
/// (feature↔feature is a hard architecture boundary), so the media model
/// slots are re-exposed here, resolved + validated.

export 'package:aetherlink_flutter/features/settings/application/media_model_controller.dart'
    show MediaModelController, mediaModelControllerProvider, MediaModelState;

/// Resolves a persisted media slot key to a [CurrentModel], returning `null`
/// when the slot is empty, unresolvable, the provider is disabled, or the
/// model no longer matches [capable]. Never falls back to the chat default.
CurrentModel? _resolveMedia(
  List<ModelProvider> providers,
  String? key,
  bool Function(Model model) capable,
) {
  final resolved = resolveAuxiliaryModel(key, providers);
  if (resolved == null) return null;
  if (!resolved.provider.isEnabled) return null;
  if (!capable(resolved.model)) return null;
  return resolved;
}

/// The configured image-generation model (validated). `null` = unconfigured
/// or stale — callers must surface an error, not substitute the chat model.
final appMediaImageModelProvider = FutureProvider<CurrentModel?>((ref) async {
  final providers = await ref.watch(appModelProvidersProvider.future);
  final key = ref.watch(
    mediaModelControllerProvider.select((s) => s.imageModelKey),
  );
  return _resolveMedia(providers, key, isGenerateImageModel);
});

/// The configured video-generation model (validated), same contract.
final appMediaVideoModelProvider = FutureProvider<CurrentModel?>((ref) async {
  final providers = await ref.watch(appModelProvidersProvider.future);
  final key = ref.watch(
    mediaModelControllerProvider.select((s) => s.videoModelKey),
  );
  return _resolveMedia(providers, key, isGenerateVideoModel);
});
