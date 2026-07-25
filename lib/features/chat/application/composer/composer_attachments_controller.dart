import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';

part 'composer_attachments_controller.g.dart';

/// The pending attachments staged in the chat composer, in insertion order.
///
/// Held purely in memory (like the web, where the converted file lives in the
/// input box's local state until send): a full restart clears it. The composer
/// adds an entry when long pasted text is converted to a file, removes one when
/// its chip's ✕ is tapped, and clears them all once the message is sent.
@Riverpod(keepAlive: true)
class ComposerAttachments extends _$ComposerAttachments {
  @override
  List<ComposerAttachment> build() => const <ComposerAttachment>[];

  void add(ComposerAttachment attachment) =>
      state = <ComposerAttachment>[...state, attachment];

  void removeById(String id) => state = <ComposerAttachment>[
    for (final a in state)
      if (a.id != id) a,
  ];

  void clear() {
    if (state.isNotEmpty) state = const <ComposerAttachment>[];
  }
}
