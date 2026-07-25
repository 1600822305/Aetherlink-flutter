import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/composer/composer_attachments_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/notes/application/notes_controller.dart';
import 'package:aetherlink_flutter/features/notes/presentation/mobile/note_picker.dart';

part 'notes_attachment_access.g.dart';

/// App-level seam that lets the chat composer attach a note. The note picker
/// lives in `notes/presentation` and the composer staging area in
/// `chat/application`; composing them here keeps the feature boundary intact.
@Riverpod(keepAlive: true)
NotesAttachmentService notesAttachmentService(Ref ref) =>
    NotesAttachmentService(ref);

class NotesAttachmentService {
  const NotesAttachmentService(this._ref);

  final Ref _ref;

  /// Opens the note picker; on selection, reads the note's markdown and stages
  /// it as a text composer attachment. Returns the attached note title, or
  /// `null` if cancelled.
  Future<String?> pickAndAttach(BuildContext context) async {
    final node = await showNotePicker(context);
    if (node == null) return null;

    final content = await _ref.read(notesFileStoreProvider).read(
      node.relativePath,
    );
    _ref.read(composerAttachmentsProvider.notifier).add(
      ComposerAttachment(
        id: generateId('note'),
        name: '${node.title}.md',
        mimeType: 'text/markdown',
        size: utf8.encode(content).length,
        kind: ComposerAttachmentKind.text,
        text: content,
      ),
    );
    return node.title;
  }
}
