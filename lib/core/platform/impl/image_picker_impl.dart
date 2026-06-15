import 'package:image_picker/image_picker.dart';

import 'package:aetherlink_flutter/core/platform/image_picker_api.dart';

/// [ImagePickerApi] backed by `image_picker`. The only place the plugin is
/// imported.
class PluginImagePickerApi implements ImagePickerApi {
  PluginImagePickerApi([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedImage?> pickFromCamera() => _pickSingle(ImageSource.camera);

  @override
  Future<PickedImage?> pickFromGallery() => _pickSingle(ImageSource.gallery);

  @override
  Future<List<PickedImage>> pickMultipleFromGallery() async {
    final files = await _picker.pickMultiImage();
    return Future.wait(files.map(_toPickedImage));
  }

  Future<PickedImage?> _pickSingle(ImageSource source) async {
    final file = await _picker.pickImage(source: source);
    if (file == null) {
      return null;
    }
    return _toPickedImage(file);
  }

  Future<PickedImage> _toPickedImage(XFile file) async {
    final bytes = await file.readAsBytes();
    return PickedImage(name: file.name, path: file.path, bytes: bytes);
  }
}
