// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'composer_attachments_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The pending attachments staged in the chat composer, in insertion order.
///
/// Held purely in memory (like the web, where the converted file lives in the
/// input box's local state until send): a full restart clears it. The composer
/// adds an entry when long pasted text is converted to a file, removes one when
/// its chip's ✕ is tapped, and clears them all once the message is sent.

@ProviderFor(ComposerAttachments)
final composerAttachmentsProvider = ComposerAttachmentsProvider._();

/// The pending attachments staged in the chat composer, in insertion order.
///
/// Held purely in memory (like the web, where the converted file lives in the
/// input box's local state until send): a full restart clears it. The composer
/// adds an entry when long pasted text is converted to a file, removes one when
/// its chip's ✕ is tapped, and clears them all once the message is sent.
final class ComposerAttachmentsProvider
    extends $NotifierProvider<ComposerAttachments, List<ComposerAttachment>> {
  /// The pending attachments staged in the chat composer, in insertion order.
  ///
  /// Held purely in memory (like the web, where the converted file lives in the
  /// input box's local state until send): a full restart clears it. The composer
  /// adds an entry when long pasted text is converted to a file, removes one when
  /// its chip's ✕ is tapped, and clears them all once the message is sent.
  ComposerAttachmentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'composerAttachmentsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$composerAttachmentsHash();

  @$internal
  @override
  ComposerAttachments create() => ComposerAttachments();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ComposerAttachment> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ComposerAttachment>>(value),
    );
  }
}

String _$composerAttachmentsHash() =>
    r'215a14230ffd13dc94b0fd5e30a32795f19ffdb5';

/// The pending attachments staged in the chat composer, in insertion order.
///
/// Held purely in memory (like the web, where the converted file lives in the
/// input box's local state until send): a full restart clears it. The composer
/// adds an entry when long pasted text is converted to a file, removes one when
/// its chip's ✕ is tapped, and clears them all once the message is sent.

abstract class _$ComposerAttachments
    extends $Notifier<List<ComposerAttachment>> {
  List<ComposerAttachment> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<List<ComposerAttachment>, List<ComposerAttachment>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<ComposerAttachment>, List<ComposerAttachment>>,
              List<ComposerAttachment>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
