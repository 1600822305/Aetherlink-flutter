// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mcp_server.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$McpServer {

 String get id; String get name; McpServerType get type; bool get isActive; String? get description; String? get baseUrl; Map<String, String>? get headers; Map<String, String>? get env; List<String>? get args; List<String>? get disabledTools; Map<String, String>? get toolPermissionOverrides; String? get provider; String? get logoUrl; List<String>? get tags; McpServerCategory? get category; String? get command; String? get cwd; int? get timeout;
/// Create a copy of McpServer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpServerCopyWith<McpServer> get copyWith => _$McpServerCopyWithImpl<McpServer>(this as McpServer, _$identity);

  /// Serializes this McpServer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServer&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.description, description) || other.description == description)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&const DeepCollectionEquality().equals(other.headers, headers)&&const DeepCollectionEquality().equals(other.env, env)&&const DeepCollectionEquality().equals(other.args, args)&&const DeepCollectionEquality().equals(other.disabledTools, disabledTools)&&const DeepCollectionEquality().equals(other.toolPermissionOverrides, toolPermissionOverrides)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.category, category) || other.category == category)&&(identical(other.command, command) || other.command == command)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timeout, timeout) || other.timeout == timeout));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,isActive,description,baseUrl,const DeepCollectionEquality().hash(headers),const DeepCollectionEquality().hash(env),const DeepCollectionEquality().hash(args),const DeepCollectionEquality().hash(disabledTools),const DeepCollectionEquality().hash(toolPermissionOverrides),provider,logoUrl,const DeepCollectionEquality().hash(tags),category,command,cwd,timeout);

@override
String toString() {
  return 'McpServer(id: $id, name: $name, type: $type, isActive: $isActive, description: $description, baseUrl: $baseUrl, headers: $headers, env: $env, args: $args, disabledTools: $disabledTools, toolPermissionOverrides: $toolPermissionOverrides, provider: $provider, logoUrl: $logoUrl, tags: $tags, category: $category, command: $command, cwd: $cwd, timeout: $timeout)';
}


}

/// @nodoc
abstract mixin class $McpServerCopyWith<$Res>  {
  factory $McpServerCopyWith(McpServer value, $Res Function(McpServer) _then) = _$McpServerCopyWithImpl;
@useResult
$Res call({
 String id, String name, McpServerType type, bool isActive, String? description, String? baseUrl, Map<String, String>? headers, Map<String, String>? env, List<String>? args, List<String>? disabledTools, Map<String, String>? toolPermissionOverrides, String? provider, String? logoUrl, List<String>? tags, McpServerCategory? category, String? command, String? cwd, int? timeout
});




}
/// @nodoc
class _$McpServerCopyWithImpl<$Res>
    implements $McpServerCopyWith<$Res> {
  _$McpServerCopyWithImpl(this._self, this._then);

  final McpServer _self;
  final $Res Function(McpServer) _then;

/// Create a copy of McpServer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? isActive = null,Object? description = freezed,Object? baseUrl = freezed,Object? headers = freezed,Object? env = freezed,Object? args = freezed,Object? disabledTools = freezed,Object? toolPermissionOverrides = freezed,Object? provider = freezed,Object? logoUrl = freezed,Object? tags = freezed,Object? category = freezed,Object? command = freezed,Object? cwd = freezed,Object? timeout = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as McpServerType,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,baseUrl: freezed == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String?,headers: freezed == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,env: freezed == env ? _self.env : env // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,args: freezed == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as List<String>?,disabledTools: freezed == disabledTools ? _self.disabledTools : disabledTools // ignore: cast_nullable_to_non_nullable
as List<String>?,toolPermissionOverrides: freezed == toolPermissionOverrides ? _self.toolPermissionOverrides : toolPermissionOverrides // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,tags: freezed == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as McpServerCategory?,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timeout: freezed == timeout ? _self.timeout : timeout // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [McpServer].
extension McpServerPatterns on McpServer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpServer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpServer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpServer value)  $default,){
final _that = this;
switch (_that) {
case _McpServer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpServer value)?  $default,){
final _that = this;
switch (_that) {
case _McpServer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  McpServerType type,  bool isActive,  String? description,  String? baseUrl,  Map<String, String>? headers,  Map<String, String>? env,  List<String>? args,  List<String>? disabledTools,  Map<String, String>? toolPermissionOverrides,  String? provider,  String? logoUrl,  List<String>? tags,  McpServerCategory? category,  String? command,  String? cwd,  int? timeout)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpServer() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.isActive,_that.description,_that.baseUrl,_that.headers,_that.env,_that.args,_that.disabledTools,_that.toolPermissionOverrides,_that.provider,_that.logoUrl,_that.tags,_that.category,_that.command,_that.cwd,_that.timeout);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  McpServerType type,  bool isActive,  String? description,  String? baseUrl,  Map<String, String>? headers,  Map<String, String>? env,  List<String>? args,  List<String>? disabledTools,  Map<String, String>? toolPermissionOverrides,  String? provider,  String? logoUrl,  List<String>? tags,  McpServerCategory? category,  String? command,  String? cwd,  int? timeout)  $default,) {final _that = this;
switch (_that) {
case _McpServer():
return $default(_that.id,_that.name,_that.type,_that.isActive,_that.description,_that.baseUrl,_that.headers,_that.env,_that.args,_that.disabledTools,_that.toolPermissionOverrides,_that.provider,_that.logoUrl,_that.tags,_that.category,_that.command,_that.cwd,_that.timeout);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  McpServerType type,  bool isActive,  String? description,  String? baseUrl,  Map<String, String>? headers,  Map<String, String>? env,  List<String>? args,  List<String>? disabledTools,  Map<String, String>? toolPermissionOverrides,  String? provider,  String? logoUrl,  List<String>? tags,  McpServerCategory? category,  String? command,  String? cwd,  int? timeout)?  $default,) {final _that = this;
switch (_that) {
case _McpServer() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.isActive,_that.description,_that.baseUrl,_that.headers,_that.env,_that.args,_that.disabledTools,_that.toolPermissionOverrides,_that.provider,_that.logoUrl,_that.tags,_that.category,_that.command,_that.cwd,_that.timeout);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McpServer implements McpServer {
  const _McpServer({required this.id, required this.name, required this.type, this.isActive = false, this.description, this.baseUrl, final  Map<String, String>? headers, final  Map<String, String>? env, final  List<String>? args, final  List<String>? disabledTools, final  Map<String, String>? toolPermissionOverrides, this.provider, this.logoUrl, final  List<String>? tags, this.category, this.command, this.cwd, this.timeout}): _headers = headers,_env = env,_args = args,_disabledTools = disabledTools,_toolPermissionOverrides = toolPermissionOverrides,_tags = tags;
  factory _McpServer.fromJson(Map<String, dynamic> json) => _$McpServerFromJson(json);

@override final  String id;
@override final  String name;
@override final  McpServerType type;
@override@JsonKey() final  bool isActive;
@override final  String? description;
@override final  String? baseUrl;
 final  Map<String, String>? _headers;
@override Map<String, String>? get headers {
  final value = _headers;
  if (value == null) return null;
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, String>? _env;
@override Map<String, String>? get env {
  final value = _env;
  if (value == null) return null;
  if (_env is EqualUnmodifiableMapView) return _env;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  List<String>? _args;
@override List<String>? get args {
  final value = _args;
  if (value == null) return null;
  if (_args is EqualUnmodifiableListView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<String>? _disabledTools;
@override List<String>? get disabledTools {
  final value = _disabledTools;
  if (value == null) return null;
  if (_disabledTools is EqualUnmodifiableListView) return _disabledTools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  Map<String, String>? _toolPermissionOverrides;
@override Map<String, String>? get toolPermissionOverrides {
  final value = _toolPermissionOverrides;
  if (value == null) return null;
  if (_toolPermissionOverrides is EqualUnmodifiableMapView) return _toolPermissionOverrides;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  String? provider;
@override final  String? logoUrl;
 final  List<String>? _tags;
@override List<String>? get tags {
  final value = _tags;
  if (value == null) return null;
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  McpServerCategory? category;
@override final  String? command;
@override final  String? cwd;
@override final  int? timeout;

/// Create a copy of McpServer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpServerCopyWith<_McpServer> get copyWith => __$McpServerCopyWithImpl<_McpServer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpServerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpServer&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.description, description) || other.description == description)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&const DeepCollectionEquality().equals(other._headers, _headers)&&const DeepCollectionEquality().equals(other._env, _env)&&const DeepCollectionEquality().equals(other._args, _args)&&const DeepCollectionEquality().equals(other._disabledTools, _disabledTools)&&const DeepCollectionEquality().equals(other._toolPermissionOverrides, _toolPermissionOverrides)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.category, category) || other.category == category)&&(identical(other.command, command) || other.command == command)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timeout, timeout) || other.timeout == timeout));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,isActive,description,baseUrl,const DeepCollectionEquality().hash(_headers),const DeepCollectionEquality().hash(_env),const DeepCollectionEquality().hash(_args),const DeepCollectionEquality().hash(_disabledTools),const DeepCollectionEquality().hash(_toolPermissionOverrides),provider,logoUrl,const DeepCollectionEquality().hash(_tags),category,command,cwd,timeout);

@override
String toString() {
  return 'McpServer(id: $id, name: $name, type: $type, isActive: $isActive, description: $description, baseUrl: $baseUrl, headers: $headers, env: $env, args: $args, disabledTools: $disabledTools, toolPermissionOverrides: $toolPermissionOverrides, provider: $provider, logoUrl: $logoUrl, tags: $tags, category: $category, command: $command, cwd: $cwd, timeout: $timeout)';
}


}

/// @nodoc
abstract mixin class _$McpServerCopyWith<$Res> implements $McpServerCopyWith<$Res> {
  factory _$McpServerCopyWith(_McpServer value, $Res Function(_McpServer) _then) = __$McpServerCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, McpServerType type, bool isActive, String? description, String? baseUrl, Map<String, String>? headers, Map<String, String>? env, List<String>? args, List<String>? disabledTools, Map<String, String>? toolPermissionOverrides, String? provider, String? logoUrl, List<String>? tags, McpServerCategory? category, String? command, String? cwd, int? timeout
});




}
/// @nodoc
class __$McpServerCopyWithImpl<$Res>
    implements _$McpServerCopyWith<$Res> {
  __$McpServerCopyWithImpl(this._self, this._then);

  final _McpServer _self;
  final $Res Function(_McpServer) _then;

/// Create a copy of McpServer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? isActive = null,Object? description = freezed,Object? baseUrl = freezed,Object? headers = freezed,Object? env = freezed,Object? args = freezed,Object? disabledTools = freezed,Object? toolPermissionOverrides = freezed,Object? provider = freezed,Object? logoUrl = freezed,Object? tags = freezed,Object? category = freezed,Object? command = freezed,Object? cwd = freezed,Object? timeout = freezed,}) {
  return _then(_McpServer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as McpServerType,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,baseUrl: freezed == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String?,headers: freezed == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,env: freezed == env ? _self._env : env // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,args: freezed == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as List<String>?,disabledTools: freezed == disabledTools ? _self._disabledTools : disabledTools // ignore: cast_nullable_to_non_nullable
as List<String>?,toolPermissionOverrides: freezed == toolPermissionOverrides ? _self._toolPermissionOverrides : toolPermissionOverrides // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,tags: freezed == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as McpServerCategory?,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timeout: freezed == timeout ? _self.timeout : timeout // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
