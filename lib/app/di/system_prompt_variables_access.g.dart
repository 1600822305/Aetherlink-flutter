// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_prompt_variables_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-level composition seam exposing the 系统提示词变量注入 config
/// ([SystemPromptVariables]) to the `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat send flow cannot read [SystemPromptVariablesController] (which
/// lives in `settings/application`) directly. It instead reads this provider in
/// `app/` (the composition root, which may depend on any feature) plus the
/// pure-Dart `shared/domain` [SystemPromptVariables] type.
///
/// Reactively re-exposes the controller's state, so toggling a variable in
/// 智能体提示词集合 takes effect on the next sent message.

@ProviderFor(systemPromptVariables)
final systemPromptVariablesProvider = SystemPromptVariablesProvider._();

/// App-level composition seam exposing the 系统提示词变量注入 config
/// ([SystemPromptVariables]) to the `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat send flow cannot read [SystemPromptVariablesController] (which
/// lives in `settings/application`) directly. It instead reads this provider in
/// `app/` (the composition root, which may depend on any feature) plus the
/// pure-Dart `shared/domain` [SystemPromptVariables] type.
///
/// Reactively re-exposes the controller's state, so toggling a variable in
/// 智能体提示词集合 takes effect on the next sent message.

final class SystemPromptVariablesProvider
    extends
        $FunctionalProvider<
          SystemPromptVariables,
          SystemPromptVariables,
          SystemPromptVariables
        >
    with $Provider<SystemPromptVariables> {
  /// App-level composition seam exposing the 系统提示词变量注入 config
  /// ([SystemPromptVariables]) to the `chat` feature.
  ///
  /// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
  /// Rule 3) forbids one feature from importing another feature's `application`,
  /// so the chat send flow cannot read [SystemPromptVariablesController] (which
  /// lives in `settings/application`) directly. It instead reads this provider in
  /// `app/` (the composition root, which may depend on any feature) plus the
  /// pure-Dart `shared/domain` [SystemPromptVariables] type.
  ///
  /// Reactively re-exposes the controller's state, so toggling a variable in
  /// 智能体提示词集合 takes effect on the next sent message.
  SystemPromptVariablesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemPromptVariablesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemPromptVariablesHash();

  @$internal
  @override
  $ProviderElement<SystemPromptVariables> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SystemPromptVariables create(Ref ref) {
    return systemPromptVariables(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemPromptVariables value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemPromptVariables>(value),
    );
  }
}

String _$systemPromptVariablesHash() =>
    r'1b2530209fb470b3489eb6032f71d0b957a1257f';
