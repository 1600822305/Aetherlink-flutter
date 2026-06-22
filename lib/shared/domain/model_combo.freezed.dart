// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_combo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ComboModelEntry {

/// The model's identity key: `providerId/modelId`.
 String get modelId;/// Role within the combo: `thinking`, `generating`, or `candidate`.
 String get role;/// Execution priority (lower = runs first). Used by sequential strategy.
 int get priority;
/// Create a copy of ComboModelEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ComboModelEntryCopyWith<ComboModelEntry> get copyWith => _$ComboModelEntryCopyWithImpl<ComboModelEntry>(this as ComboModelEntry, _$identity);

  /// Serializes this ComboModelEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ComboModelEntry&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.role, role) || other.role == role)&&(identical(other.priority, priority) || other.priority == priority));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,modelId,role,priority);

@override
String toString() {
  return 'ComboModelEntry(modelId: $modelId, role: $role, priority: $priority)';
}


}

/// @nodoc
abstract mixin class $ComboModelEntryCopyWith<$Res>  {
  factory $ComboModelEntryCopyWith(ComboModelEntry value, $Res Function(ComboModelEntry) _then) = _$ComboModelEntryCopyWithImpl;
@useResult
$Res call({
 String modelId, String role, int priority
});




}
/// @nodoc
class _$ComboModelEntryCopyWithImpl<$Res>
    implements $ComboModelEntryCopyWith<$Res> {
  _$ComboModelEntryCopyWithImpl(this._self, this._then);

  final ComboModelEntry _self;
  final $Res Function(ComboModelEntry) _then;

/// Create a copy of ComboModelEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? modelId = null,Object? role = null,Object? priority = null,}) {
  return _then(_self.copyWith(
modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ComboModelEntry].
extension ComboModelEntryPatterns on ComboModelEntry {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ComboModelEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ComboModelEntry() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ComboModelEntry value)  $default,){
final _that = this;
switch (_that) {
case _ComboModelEntry():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ComboModelEntry value)?  $default,){
final _that = this;
switch (_that) {
case _ComboModelEntry() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String modelId,  String role,  int priority)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ComboModelEntry() when $default != null:
return $default(_that.modelId,_that.role,_that.priority);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String modelId,  String role,  int priority)  $default,) {final _that = this;
switch (_that) {
case _ComboModelEntry():
return $default(_that.modelId,_that.role,_that.priority);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String modelId,  String role,  int priority)?  $default,) {final _that = this;
switch (_that) {
case _ComboModelEntry() when $default != null:
return $default(_that.modelId,_that.role,_that.priority);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ComboModelEntry implements ComboModelEntry {
  const _ComboModelEntry({required this.modelId, required this.role, this.priority = 0});
  factory _ComboModelEntry.fromJson(Map<String, dynamic> json) => _$ComboModelEntryFromJson(json);

/// The model's identity key: `providerId/modelId`.
@override final  String modelId;
/// Role within the combo: `thinking`, `generating`, or `candidate`.
@override final  String role;
/// Execution priority (lower = runs first). Used by sequential strategy.
@override@JsonKey() final  int priority;

/// Create a copy of ComboModelEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ComboModelEntryCopyWith<_ComboModelEntry> get copyWith => __$ComboModelEntryCopyWithImpl<_ComboModelEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ComboModelEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ComboModelEntry&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.role, role) || other.role == role)&&(identical(other.priority, priority) || other.priority == priority));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,modelId,role,priority);

@override
String toString() {
  return 'ComboModelEntry(modelId: $modelId, role: $role, priority: $priority)';
}


}

/// @nodoc
abstract mixin class _$ComboModelEntryCopyWith<$Res> implements $ComboModelEntryCopyWith<$Res> {
  factory _$ComboModelEntryCopyWith(_ComboModelEntry value, $Res Function(_ComboModelEntry) _then) = __$ComboModelEntryCopyWithImpl;
@override @useResult
$Res call({
 String modelId, String role, int priority
});




}
/// @nodoc
class __$ComboModelEntryCopyWithImpl<$Res>
    implements _$ComboModelEntryCopyWith<$Res> {
  __$ComboModelEntryCopyWithImpl(this._self, this._then);

  final _ComboModelEntry _self;
  final $Res Function(_ComboModelEntry) _then;

/// Create a copy of ComboModelEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? modelId = null,Object? role = null,Object? priority = null,}) {
  return _then(_ComboModelEntry(
modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ModelComboConfig {

 String get id; String get name; String get description; ModelComboStrategy get strategy; bool get enabled; List<ComboModelEntry> get models;/// Whether to display the thinking model's reasoning in the chat UI.
 bool get showThinking;/// Custom prompt template for passing thinking output to the generating
/// model. `null` means use the built-in default.
 String? get handoffPrompt; String get createdAt; String get updatedAt;
/// Create a copy of ModelComboConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelComboConfigCopyWith<ModelComboConfig> get copyWith => _$ModelComboConfigCopyWithImpl<ModelComboConfig>(this as ModelComboConfig, _$identity);

  /// Serializes this ModelComboConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelComboConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.strategy, strategy) || other.strategy == strategy)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&const DeepCollectionEquality().equals(other.models, models)&&(identical(other.showThinking, showThinking) || other.showThinking == showThinking)&&(identical(other.handoffPrompt, handoffPrompt) || other.handoffPrompt == handoffPrompt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,strategy,enabled,const DeepCollectionEquality().hash(models),showThinking,handoffPrompt,createdAt,updatedAt);

@override
String toString() {
  return 'ModelComboConfig(id: $id, name: $name, description: $description, strategy: $strategy, enabled: $enabled, models: $models, showThinking: $showThinking, handoffPrompt: $handoffPrompt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ModelComboConfigCopyWith<$Res>  {
  factory $ModelComboConfigCopyWith(ModelComboConfig value, $Res Function(ModelComboConfig) _then) = _$ModelComboConfigCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description, ModelComboStrategy strategy, bool enabled, List<ComboModelEntry> models, bool showThinking, String? handoffPrompt, String createdAt, String updatedAt
});




}
/// @nodoc
class _$ModelComboConfigCopyWithImpl<$Res>
    implements $ModelComboConfigCopyWith<$Res> {
  _$ModelComboConfigCopyWithImpl(this._self, this._then);

  final ModelComboConfig _self;
  final $Res Function(ModelComboConfig) _then;

/// Create a copy of ModelComboConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? strategy = null,Object? enabled = null,Object? models = null,Object? showThinking = null,Object? handoffPrompt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,strategy: null == strategy ? _self.strategy : strategy // ignore: cast_nullable_to_non_nullable
as ModelComboStrategy,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as List<ComboModelEntry>,showThinking: null == showThinking ? _self.showThinking : showThinking // ignore: cast_nullable_to_non_nullable
as bool,handoffPrompt: freezed == handoffPrompt ? _self.handoffPrompt : handoffPrompt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelComboConfig].
extension ModelComboConfigPatterns on ModelComboConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelComboConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelComboConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelComboConfig value)  $default,){
final _that = this;
switch (_that) {
case _ModelComboConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelComboConfig value)?  $default,){
final _that = this;
switch (_that) {
case _ModelComboConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description,  ModelComboStrategy strategy,  bool enabled,  List<ComboModelEntry> models,  bool showThinking,  String? handoffPrompt,  String createdAt,  String updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelComboConfig() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.strategy,_that.enabled,_that.models,_that.showThinking,_that.handoffPrompt,_that.createdAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description,  ModelComboStrategy strategy,  bool enabled,  List<ComboModelEntry> models,  bool showThinking,  String? handoffPrompt,  String createdAt,  String updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ModelComboConfig():
return $default(_that.id,_that.name,_that.description,_that.strategy,_that.enabled,_that.models,_that.showThinking,_that.handoffPrompt,_that.createdAt,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description,  ModelComboStrategy strategy,  bool enabled,  List<ComboModelEntry> models,  bool showThinking,  String? handoffPrompt,  String createdAt,  String updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ModelComboConfig() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.strategy,_that.enabled,_that.models,_that.showThinking,_that.handoffPrompt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelComboConfig implements ModelComboConfig {
  const _ModelComboConfig({required this.id, required this.name, this.description = '', required this.strategy, this.enabled = true, final  List<ComboModelEntry> models = const <ComboModelEntry>[], this.showThinking = true, this.handoffPrompt, required this.createdAt, required this.updatedAt}): _models = models;
  factory _ModelComboConfig.fromJson(Map<String, dynamic> json) => _$ModelComboConfigFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  String description;
@override final  ModelComboStrategy strategy;
@override@JsonKey() final  bool enabled;
 final  List<ComboModelEntry> _models;
@override@JsonKey() List<ComboModelEntry> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

/// Whether to display the thinking model's reasoning in the chat UI.
@override@JsonKey() final  bool showThinking;
/// Custom prompt template for passing thinking output to the generating
/// model. `null` means use the built-in default.
@override final  String? handoffPrompt;
@override final  String createdAt;
@override final  String updatedAt;

/// Create a copy of ModelComboConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelComboConfigCopyWith<_ModelComboConfig> get copyWith => __$ModelComboConfigCopyWithImpl<_ModelComboConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelComboConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelComboConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.strategy, strategy) || other.strategy == strategy)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.showThinking, showThinking) || other.showThinking == showThinking)&&(identical(other.handoffPrompt, handoffPrompt) || other.handoffPrompt == handoffPrompt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,strategy,enabled,const DeepCollectionEquality().hash(_models),showThinking,handoffPrompt,createdAt,updatedAt);

@override
String toString() {
  return 'ModelComboConfig(id: $id, name: $name, description: $description, strategy: $strategy, enabled: $enabled, models: $models, showThinking: $showThinking, handoffPrompt: $handoffPrompt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ModelComboConfigCopyWith<$Res> implements $ModelComboConfigCopyWith<$Res> {
  factory _$ModelComboConfigCopyWith(_ModelComboConfig value, $Res Function(_ModelComboConfig) _then) = __$ModelComboConfigCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description, ModelComboStrategy strategy, bool enabled, List<ComboModelEntry> models, bool showThinking, String? handoffPrompt, String createdAt, String updatedAt
});




}
/// @nodoc
class __$ModelComboConfigCopyWithImpl<$Res>
    implements _$ModelComboConfigCopyWith<$Res> {
  __$ModelComboConfigCopyWithImpl(this._self, this._then);

  final _ModelComboConfig _self;
  final $Res Function(_ModelComboConfig) _then;

/// Create a copy of ModelComboConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? strategy = null,Object? enabled = null,Object? models = null,Object? showThinking = null,Object? handoffPrompt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_ModelComboConfig(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,strategy: null == strategy ? _self.strategy : strategy // ignore: cast_nullable_to_non_nullable
as ModelComboStrategy,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<ComboModelEntry>,showThinking: null == showThinking ? _self.showThinking : showThinking // ignore: cast_nullable_to_non_nullable
as bool,handoffPrompt: freezed == handoffPrompt ? _self.handoffPrompt : handoffPrompt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ModelComboState {

 List<ModelComboConfig> get combos; bool get enableSmartRouting; String? get routingModelId;/// The id of the currently active combo (selected in model selector), or
/// `null` when a normal (non-combo) model is active.
 String? get selectedComboId;
/// Create a copy of ModelComboState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelComboStateCopyWith<ModelComboState> get copyWith => _$ModelComboStateCopyWithImpl<ModelComboState>(this as ModelComboState, _$identity);

  /// Serializes this ModelComboState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelComboState&&const DeepCollectionEquality().equals(other.combos, combos)&&(identical(other.enableSmartRouting, enableSmartRouting) || other.enableSmartRouting == enableSmartRouting)&&(identical(other.routingModelId, routingModelId) || other.routingModelId == routingModelId)&&(identical(other.selectedComboId, selectedComboId) || other.selectedComboId == selectedComboId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(combos),enableSmartRouting,routingModelId,selectedComboId);

@override
String toString() {
  return 'ModelComboState(combos: $combos, enableSmartRouting: $enableSmartRouting, routingModelId: $routingModelId, selectedComboId: $selectedComboId)';
}


}

/// @nodoc
abstract mixin class $ModelComboStateCopyWith<$Res>  {
  factory $ModelComboStateCopyWith(ModelComboState value, $Res Function(ModelComboState) _then) = _$ModelComboStateCopyWithImpl;
@useResult
$Res call({
 List<ModelComboConfig> combos, bool enableSmartRouting, String? routingModelId, String? selectedComboId
});




}
/// @nodoc
class _$ModelComboStateCopyWithImpl<$Res>
    implements $ModelComboStateCopyWith<$Res> {
  _$ModelComboStateCopyWithImpl(this._self, this._then);

  final ModelComboState _self;
  final $Res Function(ModelComboState) _then;

/// Create a copy of ModelComboState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? combos = null,Object? enableSmartRouting = null,Object? routingModelId = freezed,Object? selectedComboId = freezed,}) {
  return _then(_self.copyWith(
combos: null == combos ? _self.combos : combos // ignore: cast_nullable_to_non_nullable
as List<ModelComboConfig>,enableSmartRouting: null == enableSmartRouting ? _self.enableSmartRouting : enableSmartRouting // ignore: cast_nullable_to_non_nullable
as bool,routingModelId: freezed == routingModelId ? _self.routingModelId : routingModelId // ignore: cast_nullable_to_non_nullable
as String?,selectedComboId: freezed == selectedComboId ? _self.selectedComboId : selectedComboId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelComboState].
extension ModelComboStatePatterns on ModelComboState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelComboState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelComboState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelComboState value)  $default,){
final _that = this;
switch (_that) {
case _ModelComboState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelComboState value)?  $default,){
final _that = this;
switch (_that) {
case _ModelComboState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ModelComboConfig> combos,  bool enableSmartRouting,  String? routingModelId,  String? selectedComboId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelComboState() when $default != null:
return $default(_that.combos,_that.enableSmartRouting,_that.routingModelId,_that.selectedComboId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ModelComboConfig> combos,  bool enableSmartRouting,  String? routingModelId,  String? selectedComboId)  $default,) {final _that = this;
switch (_that) {
case _ModelComboState():
return $default(_that.combos,_that.enableSmartRouting,_that.routingModelId,_that.selectedComboId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ModelComboConfig> combos,  bool enableSmartRouting,  String? routingModelId,  String? selectedComboId)?  $default,) {final _that = this;
switch (_that) {
case _ModelComboState() when $default != null:
return $default(_that.combos,_that.enableSmartRouting,_that.routingModelId,_that.selectedComboId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelComboState implements ModelComboState {
  const _ModelComboState({final  List<ModelComboConfig> combos = const <ModelComboConfig>[], this.enableSmartRouting = false, this.routingModelId, this.selectedComboId}): _combos = combos;
  factory _ModelComboState.fromJson(Map<String, dynamic> json) => _$ModelComboStateFromJson(json);

 final  List<ModelComboConfig> _combos;
@override@JsonKey() List<ModelComboConfig> get combos {
  if (_combos is EqualUnmodifiableListView) return _combos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_combos);
}

@override@JsonKey() final  bool enableSmartRouting;
@override final  String? routingModelId;
/// The id of the currently active combo (selected in model selector), or
/// `null` when a normal (non-combo) model is active.
@override final  String? selectedComboId;

/// Create a copy of ModelComboState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelComboStateCopyWith<_ModelComboState> get copyWith => __$ModelComboStateCopyWithImpl<_ModelComboState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelComboStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelComboState&&const DeepCollectionEquality().equals(other._combos, _combos)&&(identical(other.enableSmartRouting, enableSmartRouting) || other.enableSmartRouting == enableSmartRouting)&&(identical(other.routingModelId, routingModelId) || other.routingModelId == routingModelId)&&(identical(other.selectedComboId, selectedComboId) || other.selectedComboId == selectedComboId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_combos),enableSmartRouting,routingModelId,selectedComboId);

@override
String toString() {
  return 'ModelComboState(combos: $combos, enableSmartRouting: $enableSmartRouting, routingModelId: $routingModelId, selectedComboId: $selectedComboId)';
}


}

/// @nodoc
abstract mixin class _$ModelComboStateCopyWith<$Res> implements $ModelComboStateCopyWith<$Res> {
  factory _$ModelComboStateCopyWith(_ModelComboState value, $Res Function(_ModelComboState) _then) = __$ModelComboStateCopyWithImpl;
@override @useResult
$Res call({
 List<ModelComboConfig> combos, bool enableSmartRouting, String? routingModelId, String? selectedComboId
});




}
/// @nodoc
class __$ModelComboStateCopyWithImpl<$Res>
    implements _$ModelComboStateCopyWith<$Res> {
  __$ModelComboStateCopyWithImpl(this._self, this._then);

  final _ModelComboState _self;
  final $Res Function(_ModelComboState) _then;

/// Create a copy of ModelComboState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? combos = null,Object? enableSmartRouting = null,Object? routingModelId = freezed,Object? selectedComboId = freezed,}) {
  return _then(_ModelComboState(
combos: null == combos ? _self._combos : combos // ignore: cast_nullable_to_non_nullable
as List<ModelComboConfig>,enableSmartRouting: null == enableSmartRouting ? _self.enableSmartRouting : enableSmartRouting // ignore: cast_nullable_to_non_nullable
as bool,routingModelId: freezed == routingModelId ? _self.routingModelId : routingModelId // ignore: cast_nullable_to_non_nullable
as String?,selectedComboId: freezed == selectedComboId ? _self.selectedComboId : selectedComboId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
