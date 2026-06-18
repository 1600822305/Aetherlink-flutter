// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quick_phrases_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The global (assistant-independent) 快捷短语, persisted via [ChatRepository]'s
/// key/value settings as a JSON list — the port of `QuickPhraseService`'s global
/// store. Assistant-scoped phrases live separately on `Assistant.regularPhrases`
/// (see [Assistants.addRegularPhrase]); the selector shows assistant phrases
/// first, then these.

@ProviderFor(GlobalQuickPhrases)
final globalQuickPhrasesProvider = GlobalQuickPhrasesProvider._();

/// The global (assistant-independent) 快捷短语, persisted via [ChatRepository]'s
/// key/value settings as a JSON list — the port of `QuickPhraseService`'s global
/// store. Assistant-scoped phrases live separately on `Assistant.regularPhrases`
/// (see [Assistants.addRegularPhrase]); the selector shows assistant phrases
/// first, then these.
final class GlobalQuickPhrasesProvider
    extends $AsyncNotifierProvider<GlobalQuickPhrases, List<QuickPhrase>> {
  /// The global (assistant-independent) 快捷短语, persisted via [ChatRepository]'s
  /// key/value settings as a JSON list — the port of `QuickPhraseService`'s global
  /// store. Assistant-scoped phrases live separately on `Assistant.regularPhrases`
  /// (see [Assistants.addRegularPhrase]); the selector shows assistant phrases
  /// first, then these.
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
    r'0fa1860ab94d184a6d67a149a0ebe54fc812fb84';

/// The global (assistant-independent) 快捷短语, persisted via [ChatRepository]'s
/// key/value settings as a JSON list — the port of `QuickPhraseService`'s global
/// store. Assistant-scoped phrases live separately on `Assistant.regularPhrases`
/// (see [Assistants.addRegularPhrase]); the selector shows assistant phrases
/// first, then these.

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
