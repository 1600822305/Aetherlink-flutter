// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_combo_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ModelComboController)
final modelComboControllerProvider = ModelComboControllerProvider._();

final class ModelComboControllerProvider
    extends $NotifierProvider<ModelComboController, ModelComboState> {
  ModelComboControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelComboControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelComboControllerHash();

  @$internal
  @override
  ModelComboController create() => ModelComboController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelComboState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelComboState>(value),
    );
  }
}

String _$modelComboControllerHash() =>
    r'b0706cd36562af57803a62e8bf6aa9e6c4939f1d';

abstract class _$ModelComboController extends $Notifier<ModelComboState> {
  ModelComboState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ModelComboState, ModelComboState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ModelComboState, ModelComboState>,
              ModelComboState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
