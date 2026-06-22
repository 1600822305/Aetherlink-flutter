// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_combo_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A virtual [ModelProvider] whose [Model] list is synthesized from the enabled
/// [ModelComboConfig] entries. The model selector can include this alongside
/// real providers so the user can pick a combo as their current model.

@ProviderFor(comboVirtualProvider)
final comboVirtualProviderProvider = ComboVirtualProviderProvider._();

/// A virtual [ModelProvider] whose [Model] list is synthesized from the enabled
/// [ModelComboConfig] entries. The model selector can include this alongside
/// real providers so the user can pick a combo as their current model.

final class ComboVirtualProviderProvider
    extends $FunctionalProvider<ModelProvider?, ModelProvider?, ModelProvider?>
    with $Provider<ModelProvider?> {
  /// A virtual [ModelProvider] whose [Model] list is synthesized from the enabled
  /// [ModelComboConfig] entries. The model selector can include this alongside
  /// real providers so the user can pick a combo as their current model.
  ComboVirtualProviderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'comboVirtualProviderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$comboVirtualProviderHash();

  @$internal
  @override
  $ProviderElement<ModelProvider?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelProvider? create(Ref ref) {
    return comboVirtualProvider(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelProvider? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelProvider?>(value),
    );
  }
}

String _$comboVirtualProviderHash() =>
    r'e4da642624a22226e73dcaf79fcb98d2932643b7';

/// All model providers including the virtual combo provider (if any combos are
/// enabled). Use this instead of [appModelProvidersProvider] when the combo
/// virtual models should appear in the list.

@ProviderFor(allProvidersWithCombos)
final allProvidersWithCombosProvider = AllProvidersWithCombosProvider._();

/// All model providers including the virtual combo provider (if any combos are
/// enabled). Use this instead of [appModelProvidersProvider] when the combo
/// virtual models should appear in the list.

final class AllProvidersWithCombosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ModelProvider>>,
          List<ModelProvider>,
          FutureOr<List<ModelProvider>>
        >
    with
        $FutureModifier<List<ModelProvider>>,
        $FutureProvider<List<ModelProvider>> {
  /// All model providers including the virtual combo provider (if any combos are
  /// enabled). Use this instead of [appModelProvidersProvider] when the combo
  /// virtual models should appear in the list.
  AllProvidersWithCombosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allProvidersWithCombosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allProvidersWithCombosHash();

  @$internal
  @override
  $FutureProviderElement<List<ModelProvider>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ModelProvider>> create(Ref ref) {
    return allProvidersWithCombos(ref);
  }
}

String _$allProvidersWithCombosHash() =>
    r'1f74d86c86b675c484d8f8e1c94a505fab6289dd';

/// Looks up the [ModelComboConfig] for a model id, or `null` if the model id
/// does not refer to a combo.

@ProviderFor(comboConfigForModel)
final comboConfigForModelProvider = ComboConfigForModelFamily._();

/// Looks up the [ModelComboConfig] for a model id, or `null` if the model id
/// does not refer to a combo.

final class ComboConfigForModelProvider
    extends
        $FunctionalProvider<
          ModelComboConfig?,
          ModelComboConfig?,
          ModelComboConfig?
        >
    with $Provider<ModelComboConfig?> {
  /// Looks up the [ModelComboConfig] for a model id, or `null` if the model id
  /// does not refer to a combo.
  ComboConfigForModelProvider._({
    required ComboConfigForModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'comboConfigForModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$comboConfigForModelHash();

  @override
  String toString() {
    return r'comboConfigForModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ModelComboConfig?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ModelComboConfig? create(Ref ref) {
    final argument = this.argument as String;
    return comboConfigForModel(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelComboConfig? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelComboConfig?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ComboConfigForModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$comboConfigForModelHash() =>
    r'bb9e9b581ebaba60a48cd25de197f04b4b07bc63';

/// Looks up the [ModelComboConfig] for a model id, or `null` if the model id
/// does not refer to a combo.

final class ComboConfigForModelFamily extends $Family
    with $FunctionalFamilyOverride<ModelComboConfig?, String> {
  ComboConfigForModelFamily._()
    : super(
        retry: null,
        name: r'comboConfigForModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Looks up the [ModelComboConfig] for a model id, or `null` if the model id
  /// does not refer to a combo.

  ComboConfigForModelProvider call(String modelId) =>
      ComboConfigForModelProvider._(argument: modelId, from: this);

  @override
  String toString() => r'comboConfigForModelProvider';
}
