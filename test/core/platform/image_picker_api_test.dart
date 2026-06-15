import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path/path.dart' as p;

import 'package:aetherlink_flutter/core/platform/impl/image_picker_impl.dart';

/// A fake `image_picker` platform that returns canned [XFile]s, so the real
/// impl's XFile -> PickedImage mapping can be tested without a real device.
class _FakeImagePickerPlatform extends ImagePickerPlatform {
  _FakeImagePickerPlatform(this.files);

  final List<XFile> files;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => files.isEmpty ? null : files.first;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => files;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File imageFile;
  final bytes = Uint8List.fromList([9, 8, 7, 6]);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aetherlink_img_test');
    imageFile = File(p.join(tempDir.path, 'photo.png'));
    await imageFile.writeAsBytes(bytes);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'maps a gallery pick to PickedImage with name, path and bytes',
    () async {
      ImagePickerPlatform.instance = _FakeImagePickerPlatform([
        XFile(imageFile.path),
      ]);
      final picker = PluginImagePickerApi();

      final picked = await picker.pickFromGallery();

      expect(picked, isNotNull);
      expect(picked!.name, 'photo.png');
      expect(picked.path, imageFile.path);
      expect(picked.bytes, bytes);
    },
  );

  test('returns null when the user cancels', () async {
    ImagePickerPlatform.instance = _FakeImagePickerPlatform(<XFile>[]);
    final picker = PluginImagePickerApi();

    expect(await picker.pickFromCamera(), isNull);
    expect(await picker.pickFromGallery(), isNull);
  });

  test('maps multiple gallery picks', () async {
    ImagePickerPlatform.instance = _FakeImagePickerPlatform([
      XFile(imageFile.path),
    ]);
    final picker = PluginImagePickerApi();

    final picked = await picker.pickMultipleFromGallery();

    expect(picked, hasLength(1));
    expect(picked.first.bytes, bytes);
  });
}
