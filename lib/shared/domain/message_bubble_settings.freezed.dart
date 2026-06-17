// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_bubble_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CustomBubbleColors {

 String get userBubbleColor; String get userTextColor; String get aiBubbleColor; String get aiTextColor;
/// Create a copy of CustomBubbleColors
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomBubbleColorsCopyWith<CustomBubbleColors> get copyWith => _$CustomBubbleColorsCopyWithImpl<CustomBubbleColors>(this as CustomBubbleColors, _$identity);

  /// Serializes this CustomBubbleColors to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomBubbleColors&&(identical(other.userBubbleColor, userBubbleColor) || other.userBubbleColor == userBubbleColor)&&(identical(other.userTextColor, userTextColor) || other.userTextColor == userTextColor)&&(identical(other.aiBubbleColor, aiBubbleColor) || other.aiBubbleColor == aiBubbleColor)&&(identical(other.aiTextColor, aiTextColor) || other.aiTextColor == aiTextColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userBubbleColor,userTextColor,aiBubbleColor,aiTextColor);

@override
String toString() {
  return 'CustomBubbleColors(userBubbleColor: $userBubbleColor, userTextColor: $userTextColor, aiBubbleColor: $aiBubbleColor, aiTextColor: $aiTextColor)';
}


}

/// @nodoc
abstract mixin class $CustomBubbleColorsCopyWith<$Res>  {
  factory $CustomBubbleColorsCopyWith(CustomBubbleColors value, $Res Function(CustomBubbleColors) _then) = _$CustomBubbleColorsCopyWithImpl;
@useResult
$Res call({
 String userBubbleColor, String userTextColor, String aiBubbleColor, String aiTextColor
});




}
/// @nodoc
class _$CustomBubbleColorsCopyWithImpl<$Res>
    implements $CustomBubbleColorsCopyWith<$Res> {
  _$CustomBubbleColorsCopyWithImpl(this._self, this._then);

  final CustomBubbleColors _self;
  final $Res Function(CustomBubbleColors) _then;

/// Create a copy of CustomBubbleColors
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userBubbleColor = null,Object? userTextColor = null,Object? aiBubbleColor = null,Object? aiTextColor = null,}) {
  return _then(_self.copyWith(
userBubbleColor: null == userBubbleColor ? _self.userBubbleColor : userBubbleColor // ignore: cast_nullable_to_non_nullable
as String,userTextColor: null == userTextColor ? _self.userTextColor : userTextColor // ignore: cast_nullable_to_non_nullable
as String,aiBubbleColor: null == aiBubbleColor ? _self.aiBubbleColor : aiBubbleColor // ignore: cast_nullable_to_non_nullable
as String,aiTextColor: null == aiTextColor ? _self.aiTextColor : aiTextColor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomBubbleColors].
extension CustomBubbleColorsPatterns on CustomBubbleColors {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomBubbleColors value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomBubbleColors() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomBubbleColors value)  $default,){
final _that = this;
switch (_that) {
case _CustomBubbleColors():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomBubbleColors value)?  $default,){
final _that = this;
switch (_that) {
case _CustomBubbleColors() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userBubbleColor,  String userTextColor,  String aiBubbleColor,  String aiTextColor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomBubbleColors() when $default != null:
return $default(_that.userBubbleColor,_that.userTextColor,_that.aiBubbleColor,_that.aiTextColor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userBubbleColor,  String userTextColor,  String aiBubbleColor,  String aiTextColor)  $default,) {final _that = this;
switch (_that) {
case _CustomBubbleColors():
return $default(_that.userBubbleColor,_that.userTextColor,_that.aiBubbleColor,_that.aiTextColor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userBubbleColor,  String userTextColor,  String aiBubbleColor,  String aiTextColor)?  $default,) {final _that = this;
switch (_that) {
case _CustomBubbleColors() when $default != null:
return $default(_that.userBubbleColor,_that.userTextColor,_that.aiBubbleColor,_that.aiTextColor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomBubbleColors implements CustomBubbleColors {
  const _CustomBubbleColors({this.userBubbleColor = '', this.userTextColor = '', this.aiBubbleColor = '', this.aiTextColor = ''});
  factory _CustomBubbleColors.fromJson(Map<String, dynamic> json) => _$CustomBubbleColorsFromJson(json);

@override@JsonKey() final  String userBubbleColor;
@override@JsonKey() final  String userTextColor;
@override@JsonKey() final  String aiBubbleColor;
@override@JsonKey() final  String aiTextColor;

/// Create a copy of CustomBubbleColors
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomBubbleColorsCopyWith<_CustomBubbleColors> get copyWith => __$CustomBubbleColorsCopyWithImpl<_CustomBubbleColors>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomBubbleColorsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomBubbleColors&&(identical(other.userBubbleColor, userBubbleColor) || other.userBubbleColor == userBubbleColor)&&(identical(other.userTextColor, userTextColor) || other.userTextColor == userTextColor)&&(identical(other.aiBubbleColor, aiBubbleColor) || other.aiBubbleColor == aiBubbleColor)&&(identical(other.aiTextColor, aiTextColor) || other.aiTextColor == aiTextColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userBubbleColor,userTextColor,aiBubbleColor,aiTextColor);

@override
String toString() {
  return 'CustomBubbleColors(userBubbleColor: $userBubbleColor, userTextColor: $userTextColor, aiBubbleColor: $aiBubbleColor, aiTextColor: $aiTextColor)';
}


}

/// @nodoc
abstract mixin class _$CustomBubbleColorsCopyWith<$Res> implements $CustomBubbleColorsCopyWith<$Res> {
  factory _$CustomBubbleColorsCopyWith(_CustomBubbleColors value, $Res Function(_CustomBubbleColors) _then) = __$CustomBubbleColorsCopyWithImpl;
@override @useResult
$Res call({
 String userBubbleColor, String userTextColor, String aiBubbleColor, String aiTextColor
});




}
/// @nodoc
class __$CustomBubbleColorsCopyWithImpl<$Res>
    implements _$CustomBubbleColorsCopyWith<$Res> {
  __$CustomBubbleColorsCopyWithImpl(this._self, this._then);

  final _CustomBubbleColors _self;
  final $Res Function(_CustomBubbleColors) _then;

/// Create a copy of CustomBubbleColors
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userBubbleColor = null,Object? userTextColor = null,Object? aiBubbleColor = null,Object? aiTextColor = null,}) {
  return _then(_CustomBubbleColors(
userBubbleColor: null == userBubbleColor ? _self.userBubbleColor : userBubbleColor // ignore: cast_nullable_to_non_nullable
as String,userTextColor: null == userTextColor ? _self.userTextColor : userTextColor // ignore: cast_nullable_to_non_nullable
as String,aiBubbleColor: null == aiBubbleColor ? _self.aiBubbleColor : aiBubbleColor // ignore: cast_nullable_to_non_nullable
as String,aiTextColor: null == aiTextColor ? _self.aiTextColor : aiTextColor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MessageBubbleSettings {

 MessageActionMode get messageActionMode; bool get showMicroBubbles; bool get showTTSButton; VersionSwitchStyle get versionSwitchStyle; int get messageBubbleMaxWidth; int get userMessageMaxWidth; int get messageBubbleMinWidth; bool get showUserAvatar; bool get showUserName; bool get showModelAvatar; bool get showModelName; bool get hideUserBubble; bool get hideAIBubble; CustomBubbleColors get customBubbleColors;
/// Create a copy of MessageBubbleSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageBubbleSettingsCopyWith<MessageBubbleSettings> get copyWith => _$MessageBubbleSettingsCopyWithImpl<MessageBubbleSettings>(this as MessageBubbleSettings, _$identity);

  /// Serializes this MessageBubbleSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageBubbleSettings&&(identical(other.messageActionMode, messageActionMode) || other.messageActionMode == messageActionMode)&&(identical(other.showMicroBubbles, showMicroBubbles) || other.showMicroBubbles == showMicroBubbles)&&(identical(other.showTTSButton, showTTSButton) || other.showTTSButton == showTTSButton)&&(identical(other.versionSwitchStyle, versionSwitchStyle) || other.versionSwitchStyle == versionSwitchStyle)&&(identical(other.messageBubbleMaxWidth, messageBubbleMaxWidth) || other.messageBubbleMaxWidth == messageBubbleMaxWidth)&&(identical(other.userMessageMaxWidth, userMessageMaxWidth) || other.userMessageMaxWidth == userMessageMaxWidth)&&(identical(other.messageBubbleMinWidth, messageBubbleMinWidth) || other.messageBubbleMinWidth == messageBubbleMinWidth)&&(identical(other.showUserAvatar, showUserAvatar) || other.showUserAvatar == showUserAvatar)&&(identical(other.showUserName, showUserName) || other.showUserName == showUserName)&&(identical(other.showModelAvatar, showModelAvatar) || other.showModelAvatar == showModelAvatar)&&(identical(other.showModelName, showModelName) || other.showModelName == showModelName)&&(identical(other.hideUserBubble, hideUserBubble) || other.hideUserBubble == hideUserBubble)&&(identical(other.hideAIBubble, hideAIBubble) || other.hideAIBubble == hideAIBubble)&&(identical(other.customBubbleColors, customBubbleColors) || other.customBubbleColors == customBubbleColors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,messageActionMode,showMicroBubbles,showTTSButton,versionSwitchStyle,messageBubbleMaxWidth,userMessageMaxWidth,messageBubbleMinWidth,showUserAvatar,showUserName,showModelAvatar,showModelName,hideUserBubble,hideAIBubble,customBubbleColors);

@override
String toString() {
  return 'MessageBubbleSettings(messageActionMode: $messageActionMode, showMicroBubbles: $showMicroBubbles, showTTSButton: $showTTSButton, versionSwitchStyle: $versionSwitchStyle, messageBubbleMaxWidth: $messageBubbleMaxWidth, userMessageMaxWidth: $userMessageMaxWidth, messageBubbleMinWidth: $messageBubbleMinWidth, showUserAvatar: $showUserAvatar, showUserName: $showUserName, showModelAvatar: $showModelAvatar, showModelName: $showModelName, hideUserBubble: $hideUserBubble, hideAIBubble: $hideAIBubble, customBubbleColors: $customBubbleColors)';
}


}

/// @nodoc
abstract mixin class $MessageBubbleSettingsCopyWith<$Res>  {
  factory $MessageBubbleSettingsCopyWith(MessageBubbleSettings value, $Res Function(MessageBubbleSettings) _then) = _$MessageBubbleSettingsCopyWithImpl;
@useResult
$Res call({
 MessageActionMode messageActionMode, bool showMicroBubbles, bool showTTSButton, VersionSwitchStyle versionSwitchStyle, int messageBubbleMaxWidth, int userMessageMaxWidth, int messageBubbleMinWidth, bool showUserAvatar, bool showUserName, bool showModelAvatar, bool showModelName, bool hideUserBubble, bool hideAIBubble, CustomBubbleColors customBubbleColors
});


$CustomBubbleColorsCopyWith<$Res> get customBubbleColors;

}
/// @nodoc
class _$MessageBubbleSettingsCopyWithImpl<$Res>
    implements $MessageBubbleSettingsCopyWith<$Res> {
  _$MessageBubbleSettingsCopyWithImpl(this._self, this._then);

  final MessageBubbleSettings _self;
  final $Res Function(MessageBubbleSettings) _then;

/// Create a copy of MessageBubbleSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageActionMode = null,Object? showMicroBubbles = null,Object? showTTSButton = null,Object? versionSwitchStyle = null,Object? messageBubbleMaxWidth = null,Object? userMessageMaxWidth = null,Object? messageBubbleMinWidth = null,Object? showUserAvatar = null,Object? showUserName = null,Object? showModelAvatar = null,Object? showModelName = null,Object? hideUserBubble = null,Object? hideAIBubble = null,Object? customBubbleColors = null,}) {
  return _then(_self.copyWith(
messageActionMode: null == messageActionMode ? _self.messageActionMode : messageActionMode // ignore: cast_nullable_to_non_nullable
as MessageActionMode,showMicroBubbles: null == showMicroBubbles ? _self.showMicroBubbles : showMicroBubbles // ignore: cast_nullable_to_non_nullable
as bool,showTTSButton: null == showTTSButton ? _self.showTTSButton : showTTSButton // ignore: cast_nullable_to_non_nullable
as bool,versionSwitchStyle: null == versionSwitchStyle ? _self.versionSwitchStyle : versionSwitchStyle // ignore: cast_nullable_to_non_nullable
as VersionSwitchStyle,messageBubbleMaxWidth: null == messageBubbleMaxWidth ? _self.messageBubbleMaxWidth : messageBubbleMaxWidth // ignore: cast_nullable_to_non_nullable
as int,userMessageMaxWidth: null == userMessageMaxWidth ? _self.userMessageMaxWidth : userMessageMaxWidth // ignore: cast_nullable_to_non_nullable
as int,messageBubbleMinWidth: null == messageBubbleMinWidth ? _self.messageBubbleMinWidth : messageBubbleMinWidth // ignore: cast_nullable_to_non_nullable
as int,showUserAvatar: null == showUserAvatar ? _self.showUserAvatar : showUserAvatar // ignore: cast_nullable_to_non_nullable
as bool,showUserName: null == showUserName ? _self.showUserName : showUserName // ignore: cast_nullable_to_non_nullable
as bool,showModelAvatar: null == showModelAvatar ? _self.showModelAvatar : showModelAvatar // ignore: cast_nullable_to_non_nullable
as bool,showModelName: null == showModelName ? _self.showModelName : showModelName // ignore: cast_nullable_to_non_nullable
as bool,hideUserBubble: null == hideUserBubble ? _self.hideUserBubble : hideUserBubble // ignore: cast_nullable_to_non_nullable
as bool,hideAIBubble: null == hideAIBubble ? _self.hideAIBubble : hideAIBubble // ignore: cast_nullable_to_non_nullable
as bool,customBubbleColors: null == customBubbleColors ? _self.customBubbleColors : customBubbleColors // ignore: cast_nullable_to_non_nullable
as CustomBubbleColors,
  ));
}
/// Create a copy of MessageBubbleSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CustomBubbleColorsCopyWith<$Res> get customBubbleColors {
  
  return $CustomBubbleColorsCopyWith<$Res>(_self.customBubbleColors, (value) {
    return _then(_self.copyWith(customBubbleColors: value));
  });
}
}


/// Adds pattern-matching-related methods to [MessageBubbleSettings].
extension MessageBubbleSettingsPatterns on MessageBubbleSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageBubbleSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageBubbleSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageBubbleSettings value)  $default,){
final _that = this;
switch (_that) {
case _MessageBubbleSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageBubbleSettings value)?  $default,){
final _that = this;
switch (_that) {
case _MessageBubbleSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MessageActionMode messageActionMode,  bool showMicroBubbles,  bool showTTSButton,  VersionSwitchStyle versionSwitchStyle,  int messageBubbleMaxWidth,  int userMessageMaxWidth,  int messageBubbleMinWidth,  bool showUserAvatar,  bool showUserName,  bool showModelAvatar,  bool showModelName,  bool hideUserBubble,  bool hideAIBubble,  CustomBubbleColors customBubbleColors)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageBubbleSettings() when $default != null:
return $default(_that.messageActionMode,_that.showMicroBubbles,_that.showTTSButton,_that.versionSwitchStyle,_that.messageBubbleMaxWidth,_that.userMessageMaxWidth,_that.messageBubbleMinWidth,_that.showUserAvatar,_that.showUserName,_that.showModelAvatar,_that.showModelName,_that.hideUserBubble,_that.hideAIBubble,_that.customBubbleColors);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MessageActionMode messageActionMode,  bool showMicroBubbles,  bool showTTSButton,  VersionSwitchStyle versionSwitchStyle,  int messageBubbleMaxWidth,  int userMessageMaxWidth,  int messageBubbleMinWidth,  bool showUserAvatar,  bool showUserName,  bool showModelAvatar,  bool showModelName,  bool hideUserBubble,  bool hideAIBubble,  CustomBubbleColors customBubbleColors)  $default,) {final _that = this;
switch (_that) {
case _MessageBubbleSettings():
return $default(_that.messageActionMode,_that.showMicroBubbles,_that.showTTSButton,_that.versionSwitchStyle,_that.messageBubbleMaxWidth,_that.userMessageMaxWidth,_that.messageBubbleMinWidth,_that.showUserAvatar,_that.showUserName,_that.showModelAvatar,_that.showModelName,_that.hideUserBubble,_that.hideAIBubble,_that.customBubbleColors);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MessageActionMode messageActionMode,  bool showMicroBubbles,  bool showTTSButton,  VersionSwitchStyle versionSwitchStyle,  int messageBubbleMaxWidth,  int userMessageMaxWidth,  int messageBubbleMinWidth,  bool showUserAvatar,  bool showUserName,  bool showModelAvatar,  bool showModelName,  bool hideUserBubble,  bool hideAIBubble,  CustomBubbleColors customBubbleColors)?  $default,) {final _that = this;
switch (_that) {
case _MessageBubbleSettings() when $default != null:
return $default(_that.messageActionMode,_that.showMicroBubbles,_that.showTTSButton,_that.versionSwitchStyle,_that.messageBubbleMaxWidth,_that.userMessageMaxWidth,_that.messageBubbleMinWidth,_that.showUserAvatar,_that.showUserName,_that.showModelAvatar,_that.showModelName,_that.hideUserBubble,_that.hideAIBubble,_that.customBubbleColors);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageBubbleSettings implements MessageBubbleSettings {
  const _MessageBubbleSettings({this.messageActionMode = MessageActionMode.bubbles, this.showMicroBubbles = true, this.showTTSButton = true, this.versionSwitchStyle = VersionSwitchStyle.popup, this.messageBubbleMaxWidth = 99, this.userMessageMaxWidth = 80, this.messageBubbleMinWidth = 50, this.showUserAvatar = true, this.showUserName = true, this.showModelAvatar = true, this.showModelName = true, this.hideUserBubble = false, this.hideAIBubble = false, this.customBubbleColors = const CustomBubbleColors()});
  factory _MessageBubbleSettings.fromJson(Map<String, dynamic> json) => _$MessageBubbleSettingsFromJson(json);

@override@JsonKey() final  MessageActionMode messageActionMode;
@override@JsonKey() final  bool showMicroBubbles;
@override@JsonKey() final  bool showTTSButton;
@override@JsonKey() final  VersionSwitchStyle versionSwitchStyle;
@override@JsonKey() final  int messageBubbleMaxWidth;
@override@JsonKey() final  int userMessageMaxWidth;
@override@JsonKey() final  int messageBubbleMinWidth;
@override@JsonKey() final  bool showUserAvatar;
@override@JsonKey() final  bool showUserName;
@override@JsonKey() final  bool showModelAvatar;
@override@JsonKey() final  bool showModelName;
@override@JsonKey() final  bool hideUserBubble;
@override@JsonKey() final  bool hideAIBubble;
@override@JsonKey() final  CustomBubbleColors customBubbleColors;

/// Create a copy of MessageBubbleSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageBubbleSettingsCopyWith<_MessageBubbleSettings> get copyWith => __$MessageBubbleSettingsCopyWithImpl<_MessageBubbleSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageBubbleSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageBubbleSettings&&(identical(other.messageActionMode, messageActionMode) || other.messageActionMode == messageActionMode)&&(identical(other.showMicroBubbles, showMicroBubbles) || other.showMicroBubbles == showMicroBubbles)&&(identical(other.showTTSButton, showTTSButton) || other.showTTSButton == showTTSButton)&&(identical(other.versionSwitchStyle, versionSwitchStyle) || other.versionSwitchStyle == versionSwitchStyle)&&(identical(other.messageBubbleMaxWidth, messageBubbleMaxWidth) || other.messageBubbleMaxWidth == messageBubbleMaxWidth)&&(identical(other.userMessageMaxWidth, userMessageMaxWidth) || other.userMessageMaxWidth == userMessageMaxWidth)&&(identical(other.messageBubbleMinWidth, messageBubbleMinWidth) || other.messageBubbleMinWidth == messageBubbleMinWidth)&&(identical(other.showUserAvatar, showUserAvatar) || other.showUserAvatar == showUserAvatar)&&(identical(other.showUserName, showUserName) || other.showUserName == showUserName)&&(identical(other.showModelAvatar, showModelAvatar) || other.showModelAvatar == showModelAvatar)&&(identical(other.showModelName, showModelName) || other.showModelName == showModelName)&&(identical(other.hideUserBubble, hideUserBubble) || other.hideUserBubble == hideUserBubble)&&(identical(other.hideAIBubble, hideAIBubble) || other.hideAIBubble == hideAIBubble)&&(identical(other.customBubbleColors, customBubbleColors) || other.customBubbleColors == customBubbleColors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,messageActionMode,showMicroBubbles,showTTSButton,versionSwitchStyle,messageBubbleMaxWidth,userMessageMaxWidth,messageBubbleMinWidth,showUserAvatar,showUserName,showModelAvatar,showModelName,hideUserBubble,hideAIBubble,customBubbleColors);

@override
String toString() {
  return 'MessageBubbleSettings(messageActionMode: $messageActionMode, showMicroBubbles: $showMicroBubbles, showTTSButton: $showTTSButton, versionSwitchStyle: $versionSwitchStyle, messageBubbleMaxWidth: $messageBubbleMaxWidth, userMessageMaxWidth: $userMessageMaxWidth, messageBubbleMinWidth: $messageBubbleMinWidth, showUserAvatar: $showUserAvatar, showUserName: $showUserName, showModelAvatar: $showModelAvatar, showModelName: $showModelName, hideUserBubble: $hideUserBubble, hideAIBubble: $hideAIBubble, customBubbleColors: $customBubbleColors)';
}


}

/// @nodoc
abstract mixin class _$MessageBubbleSettingsCopyWith<$Res> implements $MessageBubbleSettingsCopyWith<$Res> {
  factory _$MessageBubbleSettingsCopyWith(_MessageBubbleSettings value, $Res Function(_MessageBubbleSettings) _then) = __$MessageBubbleSettingsCopyWithImpl;
@override @useResult
$Res call({
 MessageActionMode messageActionMode, bool showMicroBubbles, bool showTTSButton, VersionSwitchStyle versionSwitchStyle, int messageBubbleMaxWidth, int userMessageMaxWidth, int messageBubbleMinWidth, bool showUserAvatar, bool showUserName, bool showModelAvatar, bool showModelName, bool hideUserBubble, bool hideAIBubble, CustomBubbleColors customBubbleColors
});


@override $CustomBubbleColorsCopyWith<$Res> get customBubbleColors;

}
/// @nodoc
class __$MessageBubbleSettingsCopyWithImpl<$Res>
    implements _$MessageBubbleSettingsCopyWith<$Res> {
  __$MessageBubbleSettingsCopyWithImpl(this._self, this._then);

  final _MessageBubbleSettings _self;
  final $Res Function(_MessageBubbleSettings) _then;

/// Create a copy of MessageBubbleSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageActionMode = null,Object? showMicroBubbles = null,Object? showTTSButton = null,Object? versionSwitchStyle = null,Object? messageBubbleMaxWidth = null,Object? userMessageMaxWidth = null,Object? messageBubbleMinWidth = null,Object? showUserAvatar = null,Object? showUserName = null,Object? showModelAvatar = null,Object? showModelName = null,Object? hideUserBubble = null,Object? hideAIBubble = null,Object? customBubbleColors = null,}) {
  return _then(_MessageBubbleSettings(
messageActionMode: null == messageActionMode ? _self.messageActionMode : messageActionMode // ignore: cast_nullable_to_non_nullable
as MessageActionMode,showMicroBubbles: null == showMicroBubbles ? _self.showMicroBubbles : showMicroBubbles // ignore: cast_nullable_to_non_nullable
as bool,showTTSButton: null == showTTSButton ? _self.showTTSButton : showTTSButton // ignore: cast_nullable_to_non_nullable
as bool,versionSwitchStyle: null == versionSwitchStyle ? _self.versionSwitchStyle : versionSwitchStyle // ignore: cast_nullable_to_non_nullable
as VersionSwitchStyle,messageBubbleMaxWidth: null == messageBubbleMaxWidth ? _self.messageBubbleMaxWidth : messageBubbleMaxWidth // ignore: cast_nullable_to_non_nullable
as int,userMessageMaxWidth: null == userMessageMaxWidth ? _self.userMessageMaxWidth : userMessageMaxWidth // ignore: cast_nullable_to_non_nullable
as int,messageBubbleMinWidth: null == messageBubbleMinWidth ? _self.messageBubbleMinWidth : messageBubbleMinWidth // ignore: cast_nullable_to_non_nullable
as int,showUserAvatar: null == showUserAvatar ? _self.showUserAvatar : showUserAvatar // ignore: cast_nullable_to_non_nullable
as bool,showUserName: null == showUserName ? _self.showUserName : showUserName // ignore: cast_nullable_to_non_nullable
as bool,showModelAvatar: null == showModelAvatar ? _self.showModelAvatar : showModelAvatar // ignore: cast_nullable_to_non_nullable
as bool,showModelName: null == showModelName ? _self.showModelName : showModelName // ignore: cast_nullable_to_non_nullable
as bool,hideUserBubble: null == hideUserBubble ? _self.hideUserBubble : hideUserBubble // ignore: cast_nullable_to_non_nullable
as bool,hideAIBubble: null == hideAIBubble ? _self.hideAIBubble : hideAIBubble // ignore: cast_nullable_to_non_nullable
as bool,customBubbleColors: null == customBubbleColors ? _self.customBubbleColors : customBubbleColors // ignore: cast_nullable_to_non_nullable
as CustomBubbleColors,
  ));
}

/// Create a copy of MessageBubbleSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CustomBubbleColorsCopyWith<$Res> get customBubbleColors {
  
  return $CustomBubbleColorsCopyWith<$Res>(_self.customBubbleColors, (value) {
    return _then(_self.copyWith(customBubbleColors: value));
  });
}
}

// dart format on
