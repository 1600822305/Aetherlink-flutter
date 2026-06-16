// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api_key_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApiKeyUsage {

 int get totalRequests; int get successfulRequests; int get failedRequests; int? get lastUsed; int get consecutiveFailures;
/// Create a copy of ApiKeyUsage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiKeyUsageCopyWith<ApiKeyUsage> get copyWith => _$ApiKeyUsageCopyWithImpl<ApiKeyUsage>(this as ApiKeyUsage, _$identity);

  /// Serializes this ApiKeyUsage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiKeyUsage&&(identical(other.totalRequests, totalRequests) || other.totalRequests == totalRequests)&&(identical(other.successfulRequests, successfulRequests) || other.successfulRequests == successfulRequests)&&(identical(other.failedRequests, failedRequests) || other.failedRequests == failedRequests)&&(identical(other.lastUsed, lastUsed) || other.lastUsed == lastUsed)&&(identical(other.consecutiveFailures, consecutiveFailures) || other.consecutiveFailures == consecutiveFailures));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalRequests,successfulRequests,failedRequests,lastUsed,consecutiveFailures);

@override
String toString() {
  return 'ApiKeyUsage(totalRequests: $totalRequests, successfulRequests: $successfulRequests, failedRequests: $failedRequests, lastUsed: $lastUsed, consecutiveFailures: $consecutiveFailures)';
}


}

/// @nodoc
abstract mixin class $ApiKeyUsageCopyWith<$Res>  {
  factory $ApiKeyUsageCopyWith(ApiKeyUsage value, $Res Function(ApiKeyUsage) _then) = _$ApiKeyUsageCopyWithImpl;
@useResult
$Res call({
 int totalRequests, int successfulRequests, int failedRequests, int? lastUsed, int consecutiveFailures
});




}
/// @nodoc
class _$ApiKeyUsageCopyWithImpl<$Res>
    implements $ApiKeyUsageCopyWith<$Res> {
  _$ApiKeyUsageCopyWithImpl(this._self, this._then);

  final ApiKeyUsage _self;
  final $Res Function(ApiKeyUsage) _then;

/// Create a copy of ApiKeyUsage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalRequests = null,Object? successfulRequests = null,Object? failedRequests = null,Object? lastUsed = freezed,Object? consecutiveFailures = null,}) {
  return _then(_self.copyWith(
totalRequests: null == totalRequests ? _self.totalRequests : totalRequests // ignore: cast_nullable_to_non_nullable
as int,successfulRequests: null == successfulRequests ? _self.successfulRequests : successfulRequests // ignore: cast_nullable_to_non_nullable
as int,failedRequests: null == failedRequests ? _self.failedRequests : failedRequests // ignore: cast_nullable_to_non_nullable
as int,lastUsed: freezed == lastUsed ? _self.lastUsed : lastUsed // ignore: cast_nullable_to_non_nullable
as int?,consecutiveFailures: null == consecutiveFailures ? _self.consecutiveFailures : consecutiveFailures // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ApiKeyUsage].
extension ApiKeyUsagePatterns on ApiKeyUsage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiKeyUsage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiKeyUsage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiKeyUsage value)  $default,){
final _that = this;
switch (_that) {
case _ApiKeyUsage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiKeyUsage value)?  $default,){
final _that = this;
switch (_that) {
case _ApiKeyUsage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalRequests,  int successfulRequests,  int failedRequests,  int? lastUsed,  int consecutiveFailures)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiKeyUsage() when $default != null:
return $default(_that.totalRequests,_that.successfulRequests,_that.failedRequests,_that.lastUsed,_that.consecutiveFailures);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalRequests,  int successfulRequests,  int failedRequests,  int? lastUsed,  int consecutiveFailures)  $default,) {final _that = this;
switch (_that) {
case _ApiKeyUsage():
return $default(_that.totalRequests,_that.successfulRequests,_that.failedRequests,_that.lastUsed,_that.consecutiveFailures);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalRequests,  int successfulRequests,  int failedRequests,  int? lastUsed,  int consecutiveFailures)?  $default,) {final _that = this;
switch (_that) {
case _ApiKeyUsage() when $default != null:
return $default(_that.totalRequests,_that.successfulRequests,_that.failedRequests,_that.lastUsed,_that.consecutiveFailures);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiKeyUsage implements ApiKeyUsage {
  const _ApiKeyUsage({this.totalRequests = 0, this.successfulRequests = 0, this.failedRequests = 0, this.lastUsed, this.consecutiveFailures = 0});
  factory _ApiKeyUsage.fromJson(Map<String, dynamic> json) => _$ApiKeyUsageFromJson(json);

@override@JsonKey() final  int totalRequests;
@override@JsonKey() final  int successfulRequests;
@override@JsonKey() final  int failedRequests;
@override final  int? lastUsed;
@override@JsonKey() final  int consecutiveFailures;

/// Create a copy of ApiKeyUsage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiKeyUsageCopyWith<_ApiKeyUsage> get copyWith => __$ApiKeyUsageCopyWithImpl<_ApiKeyUsage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiKeyUsageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiKeyUsage&&(identical(other.totalRequests, totalRequests) || other.totalRequests == totalRequests)&&(identical(other.successfulRequests, successfulRequests) || other.successfulRequests == successfulRequests)&&(identical(other.failedRequests, failedRequests) || other.failedRequests == failedRequests)&&(identical(other.lastUsed, lastUsed) || other.lastUsed == lastUsed)&&(identical(other.consecutiveFailures, consecutiveFailures) || other.consecutiveFailures == consecutiveFailures));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalRequests,successfulRequests,failedRequests,lastUsed,consecutiveFailures);

@override
String toString() {
  return 'ApiKeyUsage(totalRequests: $totalRequests, successfulRequests: $successfulRequests, failedRequests: $failedRequests, lastUsed: $lastUsed, consecutiveFailures: $consecutiveFailures)';
}


}

/// @nodoc
abstract mixin class _$ApiKeyUsageCopyWith<$Res> implements $ApiKeyUsageCopyWith<$Res> {
  factory _$ApiKeyUsageCopyWith(_ApiKeyUsage value, $Res Function(_ApiKeyUsage) _then) = __$ApiKeyUsageCopyWithImpl;
@override @useResult
$Res call({
 int totalRequests, int successfulRequests, int failedRequests, int? lastUsed, int consecutiveFailures
});




}
/// @nodoc
class __$ApiKeyUsageCopyWithImpl<$Res>
    implements _$ApiKeyUsageCopyWith<$Res> {
  __$ApiKeyUsageCopyWithImpl(this._self, this._then);

  final _ApiKeyUsage _self;
  final $Res Function(_ApiKeyUsage) _then;

/// Create a copy of ApiKeyUsage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalRequests = null,Object? successfulRequests = null,Object? failedRequests = null,Object? lastUsed = freezed,Object? consecutiveFailures = null,}) {
  return _then(_ApiKeyUsage(
totalRequests: null == totalRequests ? _self.totalRequests : totalRequests // ignore: cast_nullable_to_non_nullable
as int,successfulRequests: null == successfulRequests ? _self.successfulRequests : successfulRequests // ignore: cast_nullable_to_non_nullable
as int,failedRequests: null == failedRequests ? _self.failedRequests : failedRequests // ignore: cast_nullable_to_non_nullable
as int,lastUsed: freezed == lastUsed ? _self.lastUsed : lastUsed // ignore: cast_nullable_to_non_nullable
as int?,consecutiveFailures: null == consecutiveFailures ? _self.consecutiveFailures : consecutiveFailures // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ApiKeyConfig {

 String get id; String get key; String? get name; bool get isEnabled; int get priority; int? get maxRequestsPerMinute; ApiKeyUsage get usage; String get status; String? get lastError; int get createdAt; int get updatedAt;
/// Create a copy of ApiKeyConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiKeyConfigCopyWith<ApiKeyConfig> get copyWith => _$ApiKeyConfigCopyWithImpl<ApiKeyConfig>(this as ApiKeyConfig, _$identity);

  /// Serializes this ApiKeyConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiKeyConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.key, key) || other.key == key)&&(identical(other.name, name) || other.name == name)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.maxRequestsPerMinute, maxRequestsPerMinute) || other.maxRequestsPerMinute == maxRequestsPerMinute)&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.status, status) || other.status == status)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,key,name,isEnabled,priority,maxRequestsPerMinute,usage,status,lastError,createdAt,updatedAt);

@override
String toString() {
  return 'ApiKeyConfig(id: $id, key: $key, name: $name, isEnabled: $isEnabled, priority: $priority, maxRequestsPerMinute: $maxRequestsPerMinute, usage: $usage, status: $status, lastError: $lastError, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ApiKeyConfigCopyWith<$Res>  {
  factory $ApiKeyConfigCopyWith(ApiKeyConfig value, $Res Function(ApiKeyConfig) _then) = _$ApiKeyConfigCopyWithImpl;
@useResult
$Res call({
 String id, String key, String? name, bool isEnabled, int priority, int? maxRequestsPerMinute, ApiKeyUsage usage, String status, String? lastError, int createdAt, int updatedAt
});


$ApiKeyUsageCopyWith<$Res> get usage;

}
/// @nodoc
class _$ApiKeyConfigCopyWithImpl<$Res>
    implements $ApiKeyConfigCopyWith<$Res> {
  _$ApiKeyConfigCopyWithImpl(this._self, this._then);

  final ApiKeyConfig _self;
  final $Res Function(ApiKeyConfig) _then;

/// Create a copy of ApiKeyConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? key = null,Object? name = freezed,Object? isEnabled = null,Object? priority = null,Object? maxRequestsPerMinute = freezed,Object? usage = null,Object? status = null,Object? lastError = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,maxRequestsPerMinute: freezed == maxRequestsPerMinute ? _self.maxRequestsPerMinute : maxRequestsPerMinute // ignore: cast_nullable_to_non_nullable
as int?,usage: null == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as ApiKeyUsage,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of ApiKeyConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiKeyUsageCopyWith<$Res> get usage {
  
  return $ApiKeyUsageCopyWith<$Res>(_self.usage, (value) {
    return _then(_self.copyWith(usage: value));
  });
}
}


/// Adds pattern-matching-related methods to [ApiKeyConfig].
extension ApiKeyConfigPatterns on ApiKeyConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiKeyConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiKeyConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiKeyConfig value)  $default,){
final _that = this;
switch (_that) {
case _ApiKeyConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiKeyConfig value)?  $default,){
final _that = this;
switch (_that) {
case _ApiKeyConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String key,  String? name,  bool isEnabled,  int priority,  int? maxRequestsPerMinute,  ApiKeyUsage usage,  String status,  String? lastError,  int createdAt,  int updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiKeyConfig() when $default != null:
return $default(_that.id,_that.key,_that.name,_that.isEnabled,_that.priority,_that.maxRequestsPerMinute,_that.usage,_that.status,_that.lastError,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String key,  String? name,  bool isEnabled,  int priority,  int? maxRequestsPerMinute,  ApiKeyUsage usage,  String status,  String? lastError,  int createdAt,  int updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ApiKeyConfig():
return $default(_that.id,_that.key,_that.name,_that.isEnabled,_that.priority,_that.maxRequestsPerMinute,_that.usage,_that.status,_that.lastError,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String key,  String? name,  bool isEnabled,  int priority,  int? maxRequestsPerMinute,  ApiKeyUsage usage,  String status,  String? lastError,  int createdAt,  int updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ApiKeyConfig() when $default != null:
return $default(_that.id,_that.key,_that.name,_that.isEnabled,_that.priority,_that.maxRequestsPerMinute,_that.usage,_that.status,_that.lastError,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiKeyConfig implements ApiKeyConfig {
  const _ApiKeyConfig({required this.id, required this.key, this.name, this.isEnabled = true, this.priority = 5, this.maxRequestsPerMinute, this.usage = const ApiKeyUsage(), this.status = 'active', this.lastError, required this.createdAt, required this.updatedAt});
  factory _ApiKeyConfig.fromJson(Map<String, dynamic> json) => _$ApiKeyConfigFromJson(json);

@override final  String id;
@override final  String key;
@override final  String? name;
@override@JsonKey() final  bool isEnabled;
@override@JsonKey() final  int priority;
@override final  int? maxRequestsPerMinute;
@override@JsonKey() final  ApiKeyUsage usage;
@override@JsonKey() final  String status;
@override final  String? lastError;
@override final  int createdAt;
@override final  int updatedAt;

/// Create a copy of ApiKeyConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiKeyConfigCopyWith<_ApiKeyConfig> get copyWith => __$ApiKeyConfigCopyWithImpl<_ApiKeyConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiKeyConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiKeyConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.key, key) || other.key == key)&&(identical(other.name, name) || other.name == name)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.maxRequestsPerMinute, maxRequestsPerMinute) || other.maxRequestsPerMinute == maxRequestsPerMinute)&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.status, status) || other.status == status)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,key,name,isEnabled,priority,maxRequestsPerMinute,usage,status,lastError,createdAt,updatedAt);

@override
String toString() {
  return 'ApiKeyConfig(id: $id, key: $key, name: $name, isEnabled: $isEnabled, priority: $priority, maxRequestsPerMinute: $maxRequestsPerMinute, usage: $usage, status: $status, lastError: $lastError, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ApiKeyConfigCopyWith<$Res> implements $ApiKeyConfigCopyWith<$Res> {
  factory _$ApiKeyConfigCopyWith(_ApiKeyConfig value, $Res Function(_ApiKeyConfig) _then) = __$ApiKeyConfigCopyWithImpl;
@override @useResult
$Res call({
 String id, String key, String? name, bool isEnabled, int priority, int? maxRequestsPerMinute, ApiKeyUsage usage, String status, String? lastError, int createdAt, int updatedAt
});


@override $ApiKeyUsageCopyWith<$Res> get usage;

}
/// @nodoc
class __$ApiKeyConfigCopyWithImpl<$Res>
    implements _$ApiKeyConfigCopyWith<$Res> {
  __$ApiKeyConfigCopyWithImpl(this._self, this._then);

  final _ApiKeyConfig _self;
  final $Res Function(_ApiKeyConfig) _then;

/// Create a copy of ApiKeyConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? key = null,Object? name = freezed,Object? isEnabled = null,Object? priority = null,Object? maxRequestsPerMinute = freezed,Object? usage = null,Object? status = null,Object? lastError = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_ApiKeyConfig(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,maxRequestsPerMinute: freezed == maxRequestsPerMinute ? _self.maxRequestsPerMinute : maxRequestsPerMinute // ignore: cast_nullable_to_non_nullable
as int?,usage: null == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as ApiKeyUsage,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of ApiKeyConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiKeyUsageCopyWith<$Res> get usage {
  
  return $ApiKeyUsageCopyWith<$Res>(_self.usage, (value) {
    return _then(_self.copyWith(usage: value));
  });
}
}


/// @nodoc
mixin _$KeyManagementConfig {

 String get strategy; int get maxFailuresBeforeDisable; int get failureRecoveryTime; bool get enableAutoRecovery;
/// Create a copy of KeyManagementConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KeyManagementConfigCopyWith<KeyManagementConfig> get copyWith => _$KeyManagementConfigCopyWithImpl<KeyManagementConfig>(this as KeyManagementConfig, _$identity);

  /// Serializes this KeyManagementConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KeyManagementConfig&&(identical(other.strategy, strategy) || other.strategy == strategy)&&(identical(other.maxFailuresBeforeDisable, maxFailuresBeforeDisable) || other.maxFailuresBeforeDisable == maxFailuresBeforeDisable)&&(identical(other.failureRecoveryTime, failureRecoveryTime) || other.failureRecoveryTime == failureRecoveryTime)&&(identical(other.enableAutoRecovery, enableAutoRecovery) || other.enableAutoRecovery == enableAutoRecovery));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,strategy,maxFailuresBeforeDisable,failureRecoveryTime,enableAutoRecovery);

@override
String toString() {
  return 'KeyManagementConfig(strategy: $strategy, maxFailuresBeforeDisable: $maxFailuresBeforeDisable, failureRecoveryTime: $failureRecoveryTime, enableAutoRecovery: $enableAutoRecovery)';
}


}

/// @nodoc
abstract mixin class $KeyManagementConfigCopyWith<$Res>  {
  factory $KeyManagementConfigCopyWith(KeyManagementConfig value, $Res Function(KeyManagementConfig) _then) = _$KeyManagementConfigCopyWithImpl;
@useResult
$Res call({
 String strategy, int maxFailuresBeforeDisable, int failureRecoveryTime, bool enableAutoRecovery
});




}
/// @nodoc
class _$KeyManagementConfigCopyWithImpl<$Res>
    implements $KeyManagementConfigCopyWith<$Res> {
  _$KeyManagementConfigCopyWithImpl(this._self, this._then);

  final KeyManagementConfig _self;
  final $Res Function(KeyManagementConfig) _then;

/// Create a copy of KeyManagementConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? strategy = null,Object? maxFailuresBeforeDisable = null,Object? failureRecoveryTime = null,Object? enableAutoRecovery = null,}) {
  return _then(_self.copyWith(
strategy: null == strategy ? _self.strategy : strategy // ignore: cast_nullable_to_non_nullable
as String,maxFailuresBeforeDisable: null == maxFailuresBeforeDisable ? _self.maxFailuresBeforeDisable : maxFailuresBeforeDisable // ignore: cast_nullable_to_non_nullable
as int,failureRecoveryTime: null == failureRecoveryTime ? _self.failureRecoveryTime : failureRecoveryTime // ignore: cast_nullable_to_non_nullable
as int,enableAutoRecovery: null == enableAutoRecovery ? _self.enableAutoRecovery : enableAutoRecovery // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [KeyManagementConfig].
extension KeyManagementConfigPatterns on KeyManagementConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KeyManagementConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KeyManagementConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KeyManagementConfig value)  $default,){
final _that = this;
switch (_that) {
case _KeyManagementConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KeyManagementConfig value)?  $default,){
final _that = this;
switch (_that) {
case _KeyManagementConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String strategy,  int maxFailuresBeforeDisable,  int failureRecoveryTime,  bool enableAutoRecovery)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KeyManagementConfig() when $default != null:
return $default(_that.strategy,_that.maxFailuresBeforeDisable,_that.failureRecoveryTime,_that.enableAutoRecovery);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String strategy,  int maxFailuresBeforeDisable,  int failureRecoveryTime,  bool enableAutoRecovery)  $default,) {final _that = this;
switch (_that) {
case _KeyManagementConfig():
return $default(_that.strategy,_that.maxFailuresBeforeDisable,_that.failureRecoveryTime,_that.enableAutoRecovery);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String strategy,  int maxFailuresBeforeDisable,  int failureRecoveryTime,  bool enableAutoRecovery)?  $default,) {final _that = this;
switch (_that) {
case _KeyManagementConfig() when $default != null:
return $default(_that.strategy,_that.maxFailuresBeforeDisable,_that.failureRecoveryTime,_that.enableAutoRecovery);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KeyManagementConfig implements KeyManagementConfig {
  const _KeyManagementConfig({this.strategy = 'round_robin', this.maxFailuresBeforeDisable = 3, this.failureRecoveryTime = 5, this.enableAutoRecovery = true});
  factory _KeyManagementConfig.fromJson(Map<String, dynamic> json) => _$KeyManagementConfigFromJson(json);

@override@JsonKey() final  String strategy;
@override@JsonKey() final  int maxFailuresBeforeDisable;
@override@JsonKey() final  int failureRecoveryTime;
@override@JsonKey() final  bool enableAutoRecovery;

/// Create a copy of KeyManagementConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KeyManagementConfigCopyWith<_KeyManagementConfig> get copyWith => __$KeyManagementConfigCopyWithImpl<_KeyManagementConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KeyManagementConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KeyManagementConfig&&(identical(other.strategy, strategy) || other.strategy == strategy)&&(identical(other.maxFailuresBeforeDisable, maxFailuresBeforeDisable) || other.maxFailuresBeforeDisable == maxFailuresBeforeDisable)&&(identical(other.failureRecoveryTime, failureRecoveryTime) || other.failureRecoveryTime == failureRecoveryTime)&&(identical(other.enableAutoRecovery, enableAutoRecovery) || other.enableAutoRecovery == enableAutoRecovery));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,strategy,maxFailuresBeforeDisable,failureRecoveryTime,enableAutoRecovery);

@override
String toString() {
  return 'KeyManagementConfig(strategy: $strategy, maxFailuresBeforeDisable: $maxFailuresBeforeDisable, failureRecoveryTime: $failureRecoveryTime, enableAutoRecovery: $enableAutoRecovery)';
}


}

/// @nodoc
abstract mixin class _$KeyManagementConfigCopyWith<$Res> implements $KeyManagementConfigCopyWith<$Res> {
  factory _$KeyManagementConfigCopyWith(_KeyManagementConfig value, $Res Function(_KeyManagementConfig) _then) = __$KeyManagementConfigCopyWithImpl;
@override @useResult
$Res call({
 String strategy, int maxFailuresBeforeDisable, int failureRecoveryTime, bool enableAutoRecovery
});




}
/// @nodoc
class __$KeyManagementConfigCopyWithImpl<$Res>
    implements _$KeyManagementConfigCopyWith<$Res> {
  __$KeyManagementConfigCopyWithImpl(this._self, this._then);

  final _KeyManagementConfig _self;
  final $Res Function(_KeyManagementConfig) _then;

/// Create a copy of KeyManagementConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? strategy = null,Object? maxFailuresBeforeDisable = null,Object? failureRecoveryTime = null,Object? enableAutoRecovery = null,}) {
  return _then(_KeyManagementConfig(
strategy: null == strategy ? _self.strategy : strategy // ignore: cast_nullable_to_non_nullable
as String,maxFailuresBeforeDisable: null == maxFailuresBeforeDisable ? _self.maxFailuresBeforeDisable : maxFailuresBeforeDisable // ignore: cast_nullable_to_non_nullable
as int,failureRecoveryTime: null == failureRecoveryTime ? _self.failureRecoveryTime : failureRecoveryTime // ignore: cast_nullable_to_non_nullable
as int,enableAutoRecovery: null == enableAutoRecovery ? _self.enableAutoRecovery : enableAutoRecovery // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
