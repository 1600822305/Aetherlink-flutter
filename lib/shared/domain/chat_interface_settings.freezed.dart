// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_interface_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatBackgroundSettings {

 bool get enabled; String get imageUrl; double get opacity; ChatBackgroundSize get size; ChatBackgroundPosition get position; ChatBackgroundRepeat get repeat; bool get showOverlay;
/// Create a copy of ChatBackgroundSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatBackgroundSettingsCopyWith<ChatBackgroundSettings> get copyWith => _$ChatBackgroundSettingsCopyWithImpl<ChatBackgroundSettings>(this as ChatBackgroundSettings, _$identity);

  /// Serializes this ChatBackgroundSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatBackgroundSettings&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.opacity, opacity) || other.opacity == opacity)&&(identical(other.size, size) || other.size == size)&&(identical(other.position, position) || other.position == position)&&(identical(other.repeat, repeat) || other.repeat == repeat)&&(identical(other.showOverlay, showOverlay) || other.showOverlay == showOverlay));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,imageUrl,opacity,size,position,repeat,showOverlay);

@override
String toString() {
  return 'ChatBackgroundSettings(enabled: $enabled, imageUrl: $imageUrl, opacity: $opacity, size: $size, position: $position, repeat: $repeat, showOverlay: $showOverlay)';
}


}

/// @nodoc
abstract mixin class $ChatBackgroundSettingsCopyWith<$Res>  {
  factory $ChatBackgroundSettingsCopyWith(ChatBackgroundSettings value, $Res Function(ChatBackgroundSettings) _then) = _$ChatBackgroundSettingsCopyWithImpl;
@useResult
$Res call({
 bool enabled, String imageUrl, double opacity, ChatBackgroundSize size, ChatBackgroundPosition position, ChatBackgroundRepeat repeat, bool showOverlay
});




}
/// @nodoc
class _$ChatBackgroundSettingsCopyWithImpl<$Res>
    implements $ChatBackgroundSettingsCopyWith<$Res> {
  _$ChatBackgroundSettingsCopyWithImpl(this._self, this._then);

  final ChatBackgroundSettings _self;
  final $Res Function(ChatBackgroundSettings) _then;

/// Create a copy of ChatBackgroundSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? imageUrl = null,Object? opacity = null,Object? size = null,Object? position = null,Object? repeat = null,Object? showOverlay = null,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as ChatBackgroundSize,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as ChatBackgroundPosition,repeat: null == repeat ? _self.repeat : repeat // ignore: cast_nullable_to_non_nullable
as ChatBackgroundRepeat,showOverlay: null == showOverlay ? _self.showOverlay : showOverlay // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatBackgroundSettings].
extension ChatBackgroundSettingsPatterns on ChatBackgroundSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatBackgroundSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatBackgroundSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatBackgroundSettings value)  $default,){
final _that = this;
switch (_that) {
case _ChatBackgroundSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatBackgroundSettings value)?  $default,){
final _that = this;
switch (_that) {
case _ChatBackgroundSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  String imageUrl,  double opacity,  ChatBackgroundSize size,  ChatBackgroundPosition position,  ChatBackgroundRepeat repeat,  bool showOverlay)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatBackgroundSettings() when $default != null:
return $default(_that.enabled,_that.imageUrl,_that.opacity,_that.size,_that.position,_that.repeat,_that.showOverlay);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  String imageUrl,  double opacity,  ChatBackgroundSize size,  ChatBackgroundPosition position,  ChatBackgroundRepeat repeat,  bool showOverlay)  $default,) {final _that = this;
switch (_that) {
case _ChatBackgroundSettings():
return $default(_that.enabled,_that.imageUrl,_that.opacity,_that.size,_that.position,_that.repeat,_that.showOverlay);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  String imageUrl,  double opacity,  ChatBackgroundSize size,  ChatBackgroundPosition position,  ChatBackgroundRepeat repeat,  bool showOverlay)?  $default,) {final _that = this;
switch (_that) {
case _ChatBackgroundSettings() when $default != null:
return $default(_that.enabled,_that.imageUrl,_that.opacity,_that.size,_that.position,_that.repeat,_that.showOverlay);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatBackgroundSettings implements ChatBackgroundSettings {
  const _ChatBackgroundSettings({this.enabled = false, this.imageUrl = '', this.opacity = 0.7, this.size = ChatBackgroundSize.cover, this.position = ChatBackgroundPosition.center, this.repeat = ChatBackgroundRepeat.noRepeat, this.showOverlay = true});
  factory _ChatBackgroundSettings.fromJson(Map<String, dynamic> json) => _$ChatBackgroundSettingsFromJson(json);

@override@JsonKey() final  bool enabled;
@override@JsonKey() final  String imageUrl;
@override@JsonKey() final  double opacity;
@override@JsonKey() final  ChatBackgroundSize size;
@override@JsonKey() final  ChatBackgroundPosition position;
@override@JsonKey() final  ChatBackgroundRepeat repeat;
@override@JsonKey() final  bool showOverlay;

/// Create a copy of ChatBackgroundSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatBackgroundSettingsCopyWith<_ChatBackgroundSettings> get copyWith => __$ChatBackgroundSettingsCopyWithImpl<_ChatBackgroundSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatBackgroundSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatBackgroundSettings&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.opacity, opacity) || other.opacity == opacity)&&(identical(other.size, size) || other.size == size)&&(identical(other.position, position) || other.position == position)&&(identical(other.repeat, repeat) || other.repeat == repeat)&&(identical(other.showOverlay, showOverlay) || other.showOverlay == showOverlay));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,imageUrl,opacity,size,position,repeat,showOverlay);

@override
String toString() {
  return 'ChatBackgroundSettings(enabled: $enabled, imageUrl: $imageUrl, opacity: $opacity, size: $size, position: $position, repeat: $repeat, showOverlay: $showOverlay)';
}


}

/// @nodoc
abstract mixin class _$ChatBackgroundSettingsCopyWith<$Res> implements $ChatBackgroundSettingsCopyWith<$Res> {
  factory _$ChatBackgroundSettingsCopyWith(_ChatBackgroundSettings value, $Res Function(_ChatBackgroundSettings) _then) = __$ChatBackgroundSettingsCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, String imageUrl, double opacity, ChatBackgroundSize size, ChatBackgroundPosition position, ChatBackgroundRepeat repeat, bool showOverlay
});




}
/// @nodoc
class __$ChatBackgroundSettingsCopyWithImpl<$Res>
    implements _$ChatBackgroundSettingsCopyWith<$Res> {
  __$ChatBackgroundSettingsCopyWithImpl(this._self, this._then);

  final _ChatBackgroundSettings _self;
  final $Res Function(_ChatBackgroundSettings) _then;

/// Create a copy of ChatBackgroundSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? imageUrl = null,Object? opacity = null,Object? size = null,Object? position = null,Object? repeat = null,Object? showOverlay = null,}) {
  return _then(_ChatBackgroundSettings(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as ChatBackgroundSize,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as ChatBackgroundPosition,repeat: null == repeat ? _self.repeat : repeat // ignore: cast_nullable_to_non_nullable
as ChatBackgroundRepeat,showOverlay: null == showOverlay ? _self.showOverlay : showOverlay // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ChatInterfaceSettings {

 MultiModelDisplayStyle get multiModelDisplayStyle; bool get showToolDetails; bool get showCitationDetails; bool get showSystemPromptBubble; ChatBackgroundSettings get background;
/// Create a copy of ChatInterfaceSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatInterfaceSettingsCopyWith<ChatInterfaceSettings> get copyWith => _$ChatInterfaceSettingsCopyWithImpl<ChatInterfaceSettings>(this as ChatInterfaceSettings, _$identity);

  /// Serializes this ChatInterfaceSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatInterfaceSettings&&(identical(other.multiModelDisplayStyle, multiModelDisplayStyle) || other.multiModelDisplayStyle == multiModelDisplayStyle)&&(identical(other.showToolDetails, showToolDetails) || other.showToolDetails == showToolDetails)&&(identical(other.showCitationDetails, showCitationDetails) || other.showCitationDetails == showCitationDetails)&&(identical(other.showSystemPromptBubble, showSystemPromptBubble) || other.showSystemPromptBubble == showSystemPromptBubble)&&(identical(other.background, background) || other.background == background));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,multiModelDisplayStyle,showToolDetails,showCitationDetails,showSystemPromptBubble,background);

@override
String toString() {
  return 'ChatInterfaceSettings(multiModelDisplayStyle: $multiModelDisplayStyle, showToolDetails: $showToolDetails, showCitationDetails: $showCitationDetails, showSystemPromptBubble: $showSystemPromptBubble, background: $background)';
}


}

/// @nodoc
abstract mixin class $ChatInterfaceSettingsCopyWith<$Res>  {
  factory $ChatInterfaceSettingsCopyWith(ChatInterfaceSettings value, $Res Function(ChatInterfaceSettings) _then) = _$ChatInterfaceSettingsCopyWithImpl;
@useResult
$Res call({
 MultiModelDisplayStyle multiModelDisplayStyle, bool showToolDetails, bool showCitationDetails, bool showSystemPromptBubble, ChatBackgroundSettings background
});


$ChatBackgroundSettingsCopyWith<$Res> get background;

}
/// @nodoc
class _$ChatInterfaceSettingsCopyWithImpl<$Res>
    implements $ChatInterfaceSettingsCopyWith<$Res> {
  _$ChatInterfaceSettingsCopyWithImpl(this._self, this._then);

  final ChatInterfaceSettings _self;
  final $Res Function(ChatInterfaceSettings) _then;

/// Create a copy of ChatInterfaceSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? multiModelDisplayStyle = null,Object? showToolDetails = null,Object? showCitationDetails = null,Object? showSystemPromptBubble = null,Object? background = null,}) {
  return _then(_self.copyWith(
multiModelDisplayStyle: null == multiModelDisplayStyle ? _self.multiModelDisplayStyle : multiModelDisplayStyle // ignore: cast_nullable_to_non_nullable
as MultiModelDisplayStyle,showToolDetails: null == showToolDetails ? _self.showToolDetails : showToolDetails // ignore: cast_nullable_to_non_nullable
as bool,showCitationDetails: null == showCitationDetails ? _self.showCitationDetails : showCitationDetails // ignore: cast_nullable_to_non_nullable
as bool,showSystemPromptBubble: null == showSystemPromptBubble ? _self.showSystemPromptBubble : showSystemPromptBubble // ignore: cast_nullable_to_non_nullable
as bool,background: null == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as ChatBackgroundSettings,
  ));
}
/// Create a copy of ChatInterfaceSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChatBackgroundSettingsCopyWith<$Res> get background {
  
  return $ChatBackgroundSettingsCopyWith<$Res>(_self.background, (value) {
    return _then(_self.copyWith(background: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChatInterfaceSettings].
extension ChatInterfaceSettingsPatterns on ChatInterfaceSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatInterfaceSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatInterfaceSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatInterfaceSettings value)  $default,){
final _that = this;
switch (_that) {
case _ChatInterfaceSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatInterfaceSettings value)?  $default,){
final _that = this;
switch (_that) {
case _ChatInterfaceSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MultiModelDisplayStyle multiModelDisplayStyle,  bool showToolDetails,  bool showCitationDetails,  bool showSystemPromptBubble,  ChatBackgroundSettings background)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatInterfaceSettings() when $default != null:
return $default(_that.multiModelDisplayStyle,_that.showToolDetails,_that.showCitationDetails,_that.showSystemPromptBubble,_that.background);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MultiModelDisplayStyle multiModelDisplayStyle,  bool showToolDetails,  bool showCitationDetails,  bool showSystemPromptBubble,  ChatBackgroundSettings background)  $default,) {final _that = this;
switch (_that) {
case _ChatInterfaceSettings():
return $default(_that.multiModelDisplayStyle,_that.showToolDetails,_that.showCitationDetails,_that.showSystemPromptBubble,_that.background);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MultiModelDisplayStyle multiModelDisplayStyle,  bool showToolDetails,  bool showCitationDetails,  bool showSystemPromptBubble,  ChatBackgroundSettings background)?  $default,) {final _that = this;
switch (_that) {
case _ChatInterfaceSettings() when $default != null:
return $default(_that.multiModelDisplayStyle,_that.showToolDetails,_that.showCitationDetails,_that.showSystemPromptBubble,_that.background);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatInterfaceSettings implements ChatInterfaceSettings {
  const _ChatInterfaceSettings({this.multiModelDisplayStyle = MultiModelDisplayStyle.horizontal, this.showToolDetails = true, this.showCitationDetails = true, this.showSystemPromptBubble = true, this.background = const ChatBackgroundSettings()});
  factory _ChatInterfaceSettings.fromJson(Map<String, dynamic> json) => _$ChatInterfaceSettingsFromJson(json);

@override@JsonKey() final  MultiModelDisplayStyle multiModelDisplayStyle;
@override@JsonKey() final  bool showToolDetails;
@override@JsonKey() final  bool showCitationDetails;
@override@JsonKey() final  bool showSystemPromptBubble;
@override@JsonKey() final  ChatBackgroundSettings background;

/// Create a copy of ChatInterfaceSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatInterfaceSettingsCopyWith<_ChatInterfaceSettings> get copyWith => __$ChatInterfaceSettingsCopyWithImpl<_ChatInterfaceSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatInterfaceSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatInterfaceSettings&&(identical(other.multiModelDisplayStyle, multiModelDisplayStyle) || other.multiModelDisplayStyle == multiModelDisplayStyle)&&(identical(other.showToolDetails, showToolDetails) || other.showToolDetails == showToolDetails)&&(identical(other.showCitationDetails, showCitationDetails) || other.showCitationDetails == showCitationDetails)&&(identical(other.showSystemPromptBubble, showSystemPromptBubble) || other.showSystemPromptBubble == showSystemPromptBubble)&&(identical(other.background, background) || other.background == background));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,multiModelDisplayStyle,showToolDetails,showCitationDetails,showSystemPromptBubble,background);

@override
String toString() {
  return 'ChatInterfaceSettings(multiModelDisplayStyle: $multiModelDisplayStyle, showToolDetails: $showToolDetails, showCitationDetails: $showCitationDetails, showSystemPromptBubble: $showSystemPromptBubble, background: $background)';
}


}

/// @nodoc
abstract mixin class _$ChatInterfaceSettingsCopyWith<$Res> implements $ChatInterfaceSettingsCopyWith<$Res> {
  factory _$ChatInterfaceSettingsCopyWith(_ChatInterfaceSettings value, $Res Function(_ChatInterfaceSettings) _then) = __$ChatInterfaceSettingsCopyWithImpl;
@override @useResult
$Res call({
 MultiModelDisplayStyle multiModelDisplayStyle, bool showToolDetails, bool showCitationDetails, bool showSystemPromptBubble, ChatBackgroundSettings background
});


@override $ChatBackgroundSettingsCopyWith<$Res> get background;

}
/// @nodoc
class __$ChatInterfaceSettingsCopyWithImpl<$Res>
    implements _$ChatInterfaceSettingsCopyWith<$Res> {
  __$ChatInterfaceSettingsCopyWithImpl(this._self, this._then);

  final _ChatInterfaceSettings _self;
  final $Res Function(_ChatInterfaceSettings) _then;

/// Create a copy of ChatInterfaceSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? multiModelDisplayStyle = null,Object? showToolDetails = null,Object? showCitationDetails = null,Object? showSystemPromptBubble = null,Object? background = null,}) {
  return _then(_ChatInterfaceSettings(
multiModelDisplayStyle: null == multiModelDisplayStyle ? _self.multiModelDisplayStyle : multiModelDisplayStyle // ignore: cast_nullable_to_non_nullable
as MultiModelDisplayStyle,showToolDetails: null == showToolDetails ? _self.showToolDetails : showToolDetails // ignore: cast_nullable_to_non_nullable
as bool,showCitationDetails: null == showCitationDetails ? _self.showCitationDetails : showCitationDetails // ignore: cast_nullable_to_non_nullable
as bool,showSystemPromptBubble: null == showSystemPromptBubble ? _self.showSystemPromptBubble : showSystemPromptBubble // ignore: cast_nullable_to_non_nullable
as bool,background: null == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as ChatBackgroundSettings,
  ));
}

/// Create a copy of ChatInterfaceSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChatBackgroundSettingsCopyWith<$Res> get background {
  
  return $ChatBackgroundSettingsCopyWith<$Res>(_self.background, (value) {
    return _then(_self.copyWith(background: value));
  });
}
}

// dart format on
