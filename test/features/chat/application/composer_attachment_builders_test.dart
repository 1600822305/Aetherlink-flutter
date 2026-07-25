import 'dart:convert';
import 'dart:typed_data';

import 'package:aetherlink_flutter/features/chat/application/composer/composer_attachment_builders.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('imageAttachment', () {
    test('stages raw base64 image bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final attachment = imageAttachment(name: 'shot.png', bytes: bytes);

      expect(attachment.kind, ComposerAttachmentKind.image);
      expect(attachment.mimeType, 'image/png');
      expect(attachment.size, 4);
      expect(attachment.base64Data, base64Encode(bytes));
      expect(attachment.text, isNull);
    });

    test('falls back to image/jpeg for a non-image mime guess', () {
      final attachment = imageAttachment(
        name: 'no-extension',
        bytes: Uint8List.fromList([0]),
      );

      expect(attachment.mimeType, 'image/jpeg');
    });
  });

  group('fileAttachment', () {
    test('UTF-8 text becomes a text attachment fed to the model', () {
      final bytes = Uint8List.fromList(utf8.encode('hello 世界'));
      final attachment = fileAttachment(name: 'note.md', bytes: bytes);

      expect(attachment.kind, ComposerAttachmentKind.text);
      expect(attachment.mimeType, 'text/plain');
      expect(attachment.text, 'hello 世界');
      expect(attachment.base64Data, isNull);
    });

    test('binary bytes become a base64 file attachment', () {
      final bytes = Uint8List.fromList([0, 159, 146, 150]);
      final attachment = fileAttachment(name: 'data.bin', bytes: bytes);

      expect(attachment.kind, ComposerAttachmentKind.file);
      expect(attachment.mimeType, 'application/octet-stream');
      expect(attachment.base64Data, base64Encode(bytes));
      expect(attachment.text, isNull);
    });
  });

  group('mimeTypeForName', () {
    test('maps common extensions, case-insensitively', () {
      expect(mimeTypeForName('a.JPG'), 'image/jpeg');
      expect(mimeTypeForName('a.json'), 'application/json');
      expect(mimeTypeForName('a.unknownext'), 'application/octet-stream');
      expect(mimeTypeForName('noext'), 'application/octet-stream');
    });
  });
}
