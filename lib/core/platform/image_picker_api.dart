import 'dart:typed_data';

/// An image chosen from the camera or the photo library.
class PickedImage {
  const PickedImage({
    required this.name,
    required this.path,
    required this.bytes,
  });

  final String name;
  final String path;
  final Uint8List bytes;
}

/// Picks images from the camera or photo gallery for multimodal messages.
///
/// Implemented with `image_picker` under `impl/`. The interface stays pure
/// Dart so callers and tests depend on the abstraction only (ADR-0007).
abstract interface class ImagePickerApi {
  /// Captures a single photo with the camera; null if cancelled/unavailable.
  Future<PickedImage?> pickFromCamera();

  /// Picks a single image from the gallery; null if cancelled.
  Future<PickedImage?> pickFromGallery();

  /// Picks multiple images from the gallery; empty if cancelled.
  Future<List<PickedImage>> pickMultipleFromGallery();
}
