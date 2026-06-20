// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_search_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs a full-database search for [request]. Returns an empty result set for a
/// blank query without touching the database.

@ProviderFor(chatSearchResults)
final chatSearchResultsProvider = ChatSearchResultsFamily._();

/// Runs a full-database search for [request]. Returns an empty result set for a
/// blank query without touching the database.

final class ChatSearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChatSearchResultSet>,
          ChatSearchResultSet,
          FutureOr<ChatSearchResultSet>
        >
    with
        $FutureModifier<ChatSearchResultSet>,
        $FutureProvider<ChatSearchResultSet> {
  /// Runs a full-database search for [request]. Returns an empty result set for a
  /// blank query without touching the database.
  ChatSearchResultsProvider._({
    required ChatSearchResultsFamily super.from,
    required ChatSearchRequest super.argument,
  }) : super(
         retry: null,
         name: r'chatSearchResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatSearchResultsHash();

  @override
  String toString() {
    return r'chatSearchResultsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ChatSearchResultSet> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ChatSearchResultSet> create(Ref ref) {
    final argument = this.argument as ChatSearchRequest;
    return chatSearchResults(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatSearchResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatSearchResultsHash() => r'e58e3ca1f08c886dfe0162000aded54a77f917a5';

/// Runs a full-database search for [request]. Returns an empty result set for a
/// blank query without touching the database.

final class ChatSearchResultsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ChatSearchResultSet>,
          ChatSearchRequest
        > {
  ChatSearchResultsFamily._()
    : super(
        retry: null,
        name: r'chatSearchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Runs a full-database search for [request]. Returns an empty result set for a
  /// blank query without touching the database.

  ChatSearchResultsProvider call(ChatSearchRequest request) =>
      ChatSearchResultsProvider._(argument: request, from: this);

  @override
  String toString() => r'chatSearchResultsProvider';
}

/// The recent-search history, newest first, capped at [_recentSearchLimit] and
/// persisted via [ChatRepository]'s key/value store (port of the web
/// `useChatSearch` `localStorage` handling).

@ProviderFor(ChatSearchRecent)
final chatSearchRecentProvider = ChatSearchRecentProvider._();

/// The recent-search history, newest first, capped at [_recentSearchLimit] and
/// persisted via [ChatRepository]'s key/value store (port of the web
/// `useChatSearch` `localStorage` handling).
final class ChatSearchRecentProvider
    extends $NotifierProvider<ChatSearchRecent, List<String>> {
  /// The recent-search history, newest first, capped at [_recentSearchLimit] and
  /// persisted via [ChatRepository]'s key/value store (port of the web
  /// `useChatSearch` `localStorage` handling).
  ChatSearchRecentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatSearchRecentProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatSearchRecentHash();

  @$internal
  @override
  ChatSearchRecent create() => ChatSearchRecent();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$chatSearchRecentHash() => r'8d28786596589f4c63ba5f794fed9de4f232a64a';

/// The recent-search history, newest first, capped at [_recentSearchLimit] and
/// persisted via [ChatRepository]'s key/value store (port of the web
/// `useChatSearch` `localStorage` handling).

abstract class _$ChatSearchRecent extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>, List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
