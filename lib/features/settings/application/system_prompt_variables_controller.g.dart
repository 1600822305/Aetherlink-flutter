// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_prompt_variables_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the 系统提示词变量注入 configuration (the original
/// `settings.systemPromptVariables`), so the 智能体提示词集合 page stays a pure view
/// and the chat send flow can read it when assembling the system prompt.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and
/// the chat send flow. Hydrated from the Drift key/value store on first build
/// and written through on every change — the port of the web
/// `dexieStorage.saveSetting` — so the configuration survives a full restart.

@ProviderFor(SystemPromptVariablesController)
final systemPromptVariablesControllerProvider =
    SystemPromptVariablesControllerProvider._();

/// Holds the 系统提示词变量注入 configuration (the original
/// `settings.systemPromptVariables`), so the 智能体提示词集合 page stays a pure view
/// and the chat send flow can read it when assembling the system prompt.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and
/// the chat send flow. Hydrated from the Drift key/value store on first build
/// and written through on every change — the port of the web
/// `dexieStorage.saveSetting` — so the configuration survives a full restart.
final class SystemPromptVariablesControllerProvider
    extends
        $NotifierProvider<
          SystemPromptVariablesController,
          SystemPromptVariables
        > {
  /// Holds the 系统提示词变量注入 configuration (the original
  /// `settings.systemPromptVariables`), so the 智能体提示词集合 page stays a pure view
  /// and the chat send flow can read it when assembling the system prompt.
  ///
  /// `keepAlive: true`: an app-level preference shared by the settings page and
  /// the chat send flow. Hydrated from the Drift key/value store on first build
  /// and written through on every change — the port of the web
  /// `dexieStorage.saveSetting` — so the configuration survives a full restart.
  SystemPromptVariablesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemPromptVariablesControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemPromptVariablesControllerHash();

  @$internal
  @override
  SystemPromptVariablesController create() => SystemPromptVariablesController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemPromptVariables value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemPromptVariables>(value),
    );
  }
}

String _$systemPromptVariablesControllerHash() =>
    r'a5772a2314bd615da1e77616129adab6d8a0eb06';

/// Holds the 系统提示词变量注入 configuration (the original
/// `settings.systemPromptVariables`), so the 智能体提示词集合 page stays a pure view
/// and the chat send flow can read it when assembling the system prompt.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and
/// the chat send flow. Hydrated from the Drift key/value store on first build
/// and written through on every change — the port of the web
/// `dexieStorage.saveSetting` — so the configuration survives a full restart.

abstract class _$SystemPromptVariablesController
    extends $Notifier<SystemPromptVariables> {
  SystemPromptVariables build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SystemPromptVariables, SystemPromptVariables>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SystemPromptVariables, SystemPromptVariables>,
              SystemPromptVariables,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
