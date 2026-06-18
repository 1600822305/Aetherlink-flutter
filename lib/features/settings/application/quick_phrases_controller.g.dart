// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quick_phrases_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The global (assistant-independent) 快捷短语, persisted through the app-level
/// key/value store as a JSON list — the port of `QuickPhraseService`'s global
/// store. The 快捷短语管理 settings page owns the full CRUD; the chat composer reads
/// the list (and inserts a phrase) through the `app/di` access seam, mirroring
/// how the input-box config flows settings → chat. Assistant-scoped phrases live
/// separately on `Assistant.regularPhrases`; the in-chat selector shows assistant
/// phrases first, then these.

@ProviderFor(GlobalQuickPhrases)
final globalQuickPhrasesProvider = GlobalQuickPhrasesProvider._();

/// The global (assistant-independent) 快捷短语, persisted through the app-level
/// key/value store as a JSON list — the port of `QuickPhraseService`'s global
/// store. The 快捷短语管理 settings page owns the full CRUD; the chat composer reads
/// the list (and inserts a phrase) through the `app/di` access seam, mirroring
/// how the input-box config flows settings → chat. Assistant-scoped phrases live
/// separately on `Assistant.regularPhrases`; the in-chat selector shows assistant
/// phrases first, then these.
final class GlobalQuickPhrasesProvider
    extends $AsyncNotifierProvider<GlobalQuickPhrases, List<QuickPhrase>> {
  /// The global (assistant-independent) 快捷短语, persisted through the app-level
  /// key/value store as a JSON list — the port of `QuickPhraseService`'s global
  /// store. The 快捷短语管理 settings page owns the full CRUD; the chat composer reads
  /// the list (and inserts a phrase) through the `app/di` access seam, mirroring
  /// how the input-box config flows settings → chat. Assistant-scoped phrases live
  /// separately on `Assistant.regularPhrases`; the in-chat selector shows assistant
  /// phrases first, then these.
  GlobalQuickPhrasesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'globalQuickPhrasesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$globalQuickPhrasesHash();

  @$internal
  @override
  GlobalQuickPhrases create() => GlobalQuickPhrases();
}

String _$globalQuickPhrasesHash() =>
    r'89606fc4b9c8a4291d9b5c7a5c12209051b65dba';

/// The global (assistant-independent) 快捷短语, persisted through the app-level
/// key/value store as a JSON list — the port of `QuickPhraseService`'s global
/// store. The 快捷短语管理 settings page owns the full CRUD; the chat composer reads
/// the list (and inserts a phrase) through the `app/di` access seam, mirroring
/// how the input-box config flows settings → chat. Assistant-scoped phrases live
/// separately on `Assistant.regularPhrases`; the in-chat selector shows assistant
/// phrases first, then these.

abstract class _$GlobalQuickPhrases extends $AsyncNotifier<List<QuickPhrase>> {
  FutureOr<List<QuickPhrase>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<QuickPhrase>>, List<QuickPhrase>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<QuickPhrase>>, List<QuickPhrase>>,
              AsyncValue<List<QuickPhrase>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the 快捷短语 button shows inside the chat 添加内容 menu (port of the web
/// `settings.showQuickPhraseButton`, gating `UploadMenu`'s quick-phrase row).
/// Toggled from the 快捷短语管理 page, read by the chat composer through the `app/di`
/// seam. Defaults to shown and survives a restart.

@ProviderFor(ShowQuickPhraseButton)
final showQuickPhraseButtonProvider = ShowQuickPhraseButtonProvider._();

/// Whether the 快捷短语 button shows inside the chat 添加内容 menu (port of the web
/// `settings.showQuickPhraseButton`, gating `UploadMenu`'s quick-phrase row).
/// Toggled from the 快捷短语管理 page, read by the chat composer through the `app/di`
/// seam. Defaults to shown and survives a restart.
final class ShowQuickPhraseButtonProvider
    extends $NotifierProvider<ShowQuickPhraseButton, bool> {
  /// Whether the 快捷短语 button shows inside the chat 添加内容 menu (port of the web
  /// `settings.showQuickPhraseButton`, gating `UploadMenu`'s quick-phrase row).
  /// Toggled from the 快捷短语管理 page, read by the chat composer through the `app/di`
  /// seam. Defaults to shown and survives a restart.
  ShowQuickPhraseButtonProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showQuickPhraseButtonProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showQuickPhraseButtonHash();

  @$internal
  @override
  ShowQuickPhraseButton create() => ShowQuickPhraseButton();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$showQuickPhraseButtonHash() =>
    r'b71e0e8e7c97a8f6e211cf0e1101cb079d092b99';

/// Whether the 快捷短语 button shows inside the chat 添加内容 menu (port of the web
/// `settings.showQuickPhraseButton`, gating `UploadMenu`'s quick-phrase row).
/// Toggled from the 快捷短语管理 page, read by the chat composer through the `app/di`
/// seam. Defaults to shown and survives a restart.

abstract class _$ShowQuickPhraseButton extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
