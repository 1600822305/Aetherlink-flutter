// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'skill.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Skill {

 String get id; String get name; String get description; SkillSource get source; String? get emoji; List<String> get tags;/// SKILL.md body (Markdown instructions). Consumed by the editor, not the
/// list page.
 String get content;/// Trigger phrase examples, e.g. `['审查代码', 'review PR']`.
 List<String> get triggerPhrases;/// Associated MCP server id.
 String? get mcpServerId;/// Recommended model / temperature.
 String? get modelOverride; double? get temperatureOverride; String? get version; String? get author; bool get enabled;/// Usage statistics.
 int? get usageCount; String? get lastUsedAt; String? get createdAt; String? get updatedAt;
/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SkillCopyWith<Skill> get copyWith => _$SkillCopyWithImpl<Skill>(this as Skill, _$identity);

  /// Serializes this Skill to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Skill&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.source, source) || other.source == source)&&(identical(other.emoji, emoji) || other.emoji == emoji)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.content, content) || other.content == content)&&const DeepCollectionEquality().equals(other.triggerPhrases, triggerPhrases)&&(identical(other.mcpServerId, mcpServerId) || other.mcpServerId == mcpServerId)&&(identical(other.modelOverride, modelOverride) || other.modelOverride == modelOverride)&&(identical(other.temperatureOverride, temperatureOverride) || other.temperatureOverride == temperatureOverride)&&(identical(other.version, version) || other.version == version)&&(identical(other.author, author) || other.author == author)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.usageCount, usageCount) || other.usageCount == usageCount)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,source,emoji,const DeepCollectionEquality().hash(tags),content,const DeepCollectionEquality().hash(triggerPhrases),mcpServerId,modelOverride,temperatureOverride,version,author,enabled,usageCount,lastUsedAt,createdAt,updatedAt);

@override
String toString() {
  return 'Skill(id: $id, name: $name, description: $description, source: $source, emoji: $emoji, tags: $tags, content: $content, triggerPhrases: $triggerPhrases, mcpServerId: $mcpServerId, modelOverride: $modelOverride, temperatureOverride: $temperatureOverride, version: $version, author: $author, enabled: $enabled, usageCount: $usageCount, lastUsedAt: $lastUsedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SkillCopyWith<$Res>  {
  factory $SkillCopyWith(Skill value, $Res Function(Skill) _then) = _$SkillCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description, SkillSource source, String? emoji, List<String> tags, String content, List<String> triggerPhrases, String? mcpServerId, String? modelOverride, double? temperatureOverride, String? version, String? author, bool enabled, int? usageCount, String? lastUsedAt, String? createdAt, String? updatedAt
});




}
/// @nodoc
class _$SkillCopyWithImpl<$Res>
    implements $SkillCopyWith<$Res> {
  _$SkillCopyWithImpl(this._self, this._then);

  final Skill _self;
  final $Res Function(Skill) _then;

/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? source = null,Object? emoji = freezed,Object? tags = null,Object? content = null,Object? triggerPhrases = null,Object? mcpServerId = freezed,Object? modelOverride = freezed,Object? temperatureOverride = freezed,Object? version = freezed,Object? author = freezed,Object? enabled = null,Object? usageCount = freezed,Object? lastUsedAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as SkillSource,emoji: freezed == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,triggerPhrases: null == triggerPhrases ? _self.triggerPhrases : triggerPhrases // ignore: cast_nullable_to_non_nullable
as List<String>,mcpServerId: freezed == mcpServerId ? _self.mcpServerId : mcpServerId // ignore: cast_nullable_to_non_nullable
as String?,modelOverride: freezed == modelOverride ? _self.modelOverride : modelOverride // ignore: cast_nullable_to_non_nullable
as String?,temperatureOverride: freezed == temperatureOverride ? _self.temperatureOverride : temperatureOverride // ignore: cast_nullable_to_non_nullable
as double?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,usageCount: freezed == usageCount ? _self.usageCount : usageCount // ignore: cast_nullable_to_non_nullable
as int?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Skill].
extension SkillPatterns on Skill {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Skill value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Skill() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Skill value)  $default,){
final _that = this;
switch (_that) {
case _Skill():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Skill value)?  $default,){
final _that = this;
switch (_that) {
case _Skill() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description,  SkillSource source,  String? emoji,  List<String> tags,  String content,  List<String> triggerPhrases,  String? mcpServerId,  String? modelOverride,  double? temperatureOverride,  String? version,  String? author,  bool enabled,  int? usageCount,  String? lastUsedAt,  String? createdAt,  String? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Skill() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.source,_that.emoji,_that.tags,_that.content,_that.triggerPhrases,_that.mcpServerId,_that.modelOverride,_that.temperatureOverride,_that.version,_that.author,_that.enabled,_that.usageCount,_that.lastUsedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description,  SkillSource source,  String? emoji,  List<String> tags,  String content,  List<String> triggerPhrases,  String? mcpServerId,  String? modelOverride,  double? temperatureOverride,  String? version,  String? author,  bool enabled,  int? usageCount,  String? lastUsedAt,  String? createdAt,  String? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Skill():
return $default(_that.id,_that.name,_that.description,_that.source,_that.emoji,_that.tags,_that.content,_that.triggerPhrases,_that.mcpServerId,_that.modelOverride,_that.temperatureOverride,_that.version,_that.author,_that.enabled,_that.usageCount,_that.lastUsedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description,  SkillSource source,  String? emoji,  List<String> tags,  String content,  List<String> triggerPhrases,  String? mcpServerId,  String? modelOverride,  double? temperatureOverride,  String? version,  String? author,  bool enabled,  int? usageCount,  String? lastUsedAt,  String? createdAt,  String? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Skill() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.source,_that.emoji,_that.tags,_that.content,_that.triggerPhrases,_that.mcpServerId,_that.modelOverride,_that.temperatureOverride,_that.version,_that.author,_that.enabled,_that.usageCount,_that.lastUsedAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Skill implements Skill {
  const _Skill({required this.id, required this.name, required this.description, required this.source, this.emoji, final  List<String> tags = const <String>[], this.content = '', final  List<String> triggerPhrases = const <String>[], this.mcpServerId, this.modelOverride, this.temperatureOverride, this.version, this.author, this.enabled = false, this.usageCount, this.lastUsedAt, this.createdAt, this.updatedAt}): _tags = tags,_triggerPhrases = triggerPhrases;
  factory _Skill.fromJson(Map<String, dynamic> json) => _$SkillFromJson(json);

@override final  String id;
@override final  String name;
@override final  String description;
@override final  SkillSource source;
@override final  String? emoji;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// SKILL.md body (Markdown instructions). Consumed by the editor, not the
/// list page.
@override@JsonKey() final  String content;
/// Trigger phrase examples, e.g. `['审查代码', 'review PR']`.
 final  List<String> _triggerPhrases;
/// Trigger phrase examples, e.g. `['审查代码', 'review PR']`.
@override@JsonKey() List<String> get triggerPhrases {
  if (_triggerPhrases is EqualUnmodifiableListView) return _triggerPhrases;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_triggerPhrases);
}

/// Associated MCP server id.
@override final  String? mcpServerId;
/// Recommended model / temperature.
@override final  String? modelOverride;
@override final  double? temperatureOverride;
@override final  String? version;
@override final  String? author;
@override@JsonKey() final  bool enabled;
/// Usage statistics.
@override final  int? usageCount;
@override final  String? lastUsedAt;
@override final  String? createdAt;
@override final  String? updatedAt;

/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SkillCopyWith<_Skill> get copyWith => __$SkillCopyWithImpl<_Skill>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SkillToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Skill&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.source, source) || other.source == source)&&(identical(other.emoji, emoji) || other.emoji == emoji)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.content, content) || other.content == content)&&const DeepCollectionEquality().equals(other._triggerPhrases, _triggerPhrases)&&(identical(other.mcpServerId, mcpServerId) || other.mcpServerId == mcpServerId)&&(identical(other.modelOverride, modelOverride) || other.modelOverride == modelOverride)&&(identical(other.temperatureOverride, temperatureOverride) || other.temperatureOverride == temperatureOverride)&&(identical(other.version, version) || other.version == version)&&(identical(other.author, author) || other.author == author)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.usageCount, usageCount) || other.usageCount == usageCount)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,source,emoji,const DeepCollectionEquality().hash(_tags),content,const DeepCollectionEquality().hash(_triggerPhrases),mcpServerId,modelOverride,temperatureOverride,version,author,enabled,usageCount,lastUsedAt,createdAt,updatedAt);

@override
String toString() {
  return 'Skill(id: $id, name: $name, description: $description, source: $source, emoji: $emoji, tags: $tags, content: $content, triggerPhrases: $triggerPhrases, mcpServerId: $mcpServerId, modelOverride: $modelOverride, temperatureOverride: $temperatureOverride, version: $version, author: $author, enabled: $enabled, usageCount: $usageCount, lastUsedAt: $lastUsedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SkillCopyWith<$Res> implements $SkillCopyWith<$Res> {
  factory _$SkillCopyWith(_Skill value, $Res Function(_Skill) _then) = __$SkillCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description, SkillSource source, String? emoji, List<String> tags, String content, List<String> triggerPhrases, String? mcpServerId, String? modelOverride, double? temperatureOverride, String? version, String? author, bool enabled, int? usageCount, String? lastUsedAt, String? createdAt, String? updatedAt
});




}
/// @nodoc
class __$SkillCopyWithImpl<$Res>
    implements _$SkillCopyWith<$Res> {
  __$SkillCopyWithImpl(this._self, this._then);

  final _Skill _self;
  final $Res Function(_Skill) _then;

/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? source = null,Object? emoji = freezed,Object? tags = null,Object? content = null,Object? triggerPhrases = null,Object? mcpServerId = freezed,Object? modelOverride = freezed,Object? temperatureOverride = freezed,Object? version = freezed,Object? author = freezed,Object? enabled = null,Object? usageCount = freezed,Object? lastUsedAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_Skill(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as SkillSource,emoji: freezed == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,triggerPhrases: null == triggerPhrases ? _self._triggerPhrases : triggerPhrases // ignore: cast_nullable_to_non_nullable
as List<String>,mcpServerId: freezed == mcpServerId ? _self.mcpServerId : mcpServerId // ignore: cast_nullable_to_non_nullable
as String?,modelOverride: freezed == modelOverride ? _self.modelOverride : modelOverride // ignore: cast_nullable_to_non_nullable
as String?,temperatureOverride: freezed == temperatureOverride ? _self.temperatureOverride : temperatureOverride // ignore: cast_nullable_to_non_nullable
as double?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,usageCount: freezed == usageCount ? _self.usageCount : usageCount // ignore: cast_nullable_to_non_nullable
as int?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
