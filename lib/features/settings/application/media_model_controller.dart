import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/chat_gateway_access.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';

part 'media_model_controller.g.dart';

/// Persisted key/value keys for the two media-generation model selections.
/// Deliberately separate from the auxiliary chat-model keys (`auxiliary_*`):
/// image/video generation models are not LLMs and must never flow into
/// title/translate/chat consumers.
const String kMediaImageModelKey = 'media_image_model';
const String kMediaVideoModelKey = 'media_video_model';

/// The complete persisted state for the image/video generation model slots.
/// Hydrated from the key/value store on first access.
class MediaModelState {
  const MediaModelState({this.imageModelKey, this.videoModelKey});

  final String? imageModelKey;
  final String? videoModelKey;

  MediaModelState copyWith({
    String? Function()? imageModelKey,
    String? Function()? videoModelKey,
  }) {
    return MediaModelState(
      imageModelKey: imageModelKey != null
          ? imageModelKey()
          : this.imageModelKey,
      videoModelKey: videoModelKey != null
          ? videoModelKey()
          : this.videoModelKey,
    );
  }
}

/// Controller that reads/writes the image/video generation model selections
/// through the [ChatRepository] key/value store. Storage format matches the
/// auxiliary model slots (`providerId<modelId>`); resolution goes through
/// [resolveAuxiliaryModel]. Capability/enabled validation lives in the DI
/// seam (`app/di/media_model_access.dart`), not here.
@Riverpod(keepAlive: true)
class MediaModelController extends _$MediaModelController {
  final Completer<void> _hydrationDone = Completer<void>();

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  /// Resolves once persisted selections have been read into state. Callers
  /// resolving the slots for a turn (`appMedia*ModelProvider`) await this so a
  /// cold-start turn never sees the pre-hydration empty state.
  Future<void> get hydrated => _hydrationDone.future;

  @override
  MediaModelState build() {
    _hydrate();
    return const MediaModelState();
  }

  Future<void> _hydrate() async {
    try {
      final results = await Future.wait([
        _repo.getSetting(kMediaImageModelKey),
        _repo.getSetting(kMediaVideoModelKey),
      ]);
      state = MediaModelState(
        imageModelKey: results[0],
        videoModelKey: results[1],
      );
    } finally {
      if (!_hydrationDone.isCompleted) _hydrationDone.complete();
    }
  }

  void setImageModel(String providerId, String modelId) {
    final key = '$providerId\u0000$modelId';
    state = state.copyWith(imageModelKey: () => key);
    _repo.saveSetting(kMediaImageModelKey, key);
  }

  void clearImageModel() {
    state = state.copyWith(imageModelKey: () => null);
    _repo.saveSetting(kMediaImageModelKey, '');
  }

  void setVideoModel(String providerId, String modelId) {
    final key = '$providerId\u0000$modelId';
    state = state.copyWith(videoModelKey: () => key);
    _repo.saveSetting(kMediaVideoModelKey, key);
  }

  void clearVideoModel() {
    state = state.copyWith(videoModelKey: () => null);
    _repo.saveSetting(kMediaVideoModelKey, '');
  }
}
