// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'behavior_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HapticFeedbackSettings {

 bool get enabled; bool get enableOnSidebar; bool get enableOnSwitch; bool get enableOnListItem; bool get enableOnNavigation;
/// Create a copy of HapticFeedbackSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HapticFeedbackSettingsCopyWith<HapticFeedbackSettings> get copyWith => _$HapticFeedbackSettingsCopyWithImpl<HapticFeedbackSettings>(this as HapticFeedbackSettings, _$identity);

  /// Serializes this HapticFeedbackSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HapticFeedbackSettings&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.enableOnSidebar, enableOnSidebar) || other.enableOnSidebar == enableOnSidebar)&&(identical(other.enableOnSwitch, enableOnSwitch) || other.enableOnSwitch == enableOnSwitch)&&(identical(other.enableOnListItem, enableOnListItem) || other.enableOnListItem == enableOnListItem)&&(identical(other.enableOnNavigation, enableOnNavigation) || other.enableOnNavigation == enableOnNavigation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,enableOnSidebar,enableOnSwitch,enableOnListItem,enableOnNavigation);

@override
String toString() {
  return 'HapticFeedbackSettings(enabled: $enabled, enableOnSidebar: $enableOnSidebar, enableOnSwitch: $enableOnSwitch, enableOnListItem: $enableOnListItem, enableOnNavigation: $enableOnNavigation)';
}


}

/// @nodoc
abstract mixin class $HapticFeedbackSettingsCopyWith<$Res>  {
  factory $HapticFeedbackSettingsCopyWith(HapticFeedbackSettings value, $Res Function(HapticFeedbackSettings) _then) = _$HapticFeedbackSettingsCopyWithImpl;
@useResult
$Res call({
 bool enabled, bool enableOnSidebar, bool enableOnSwitch, bool enableOnListItem, bool enableOnNavigation
});




}
/// @nodoc
class _$HapticFeedbackSettingsCopyWithImpl<$Res>
    implements $HapticFeedbackSettingsCopyWith<$Res> {
  _$HapticFeedbackSettingsCopyWithImpl(this._self, this._then);

  final HapticFeedbackSettings _self;
  final $Res Function(HapticFeedbackSettings) _then;

/// Create a copy of HapticFeedbackSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? enableOnSidebar = null,Object? enableOnSwitch = null,Object? enableOnListItem = null,Object? enableOnNavigation = null,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,enableOnSidebar: null == enableOnSidebar ? _self.enableOnSidebar : enableOnSidebar // ignore: cast_nullable_to_non_nullable
as bool,enableOnSwitch: null == enableOnSwitch ? _self.enableOnSwitch : enableOnSwitch // ignore: cast_nullable_to_non_nullable
as bool,enableOnListItem: null == enableOnListItem ? _self.enableOnListItem : enableOnListItem // ignore: cast_nullable_to_non_nullable
as bool,enableOnNavigation: null == enableOnNavigation ? _self.enableOnNavigation : enableOnNavigation // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [HapticFeedbackSettings].
extension HapticFeedbackSettingsPatterns on HapticFeedbackSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HapticFeedbackSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HapticFeedbackSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HapticFeedbackSettings value)  $default,){
final _that = this;
switch (_that) {
case _HapticFeedbackSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HapticFeedbackSettings value)?  $default,){
final _that = this;
switch (_that) {
case _HapticFeedbackSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  bool enableOnSidebar,  bool enableOnSwitch,  bool enableOnListItem,  bool enableOnNavigation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HapticFeedbackSettings() when $default != null:
return $default(_that.enabled,_that.enableOnSidebar,_that.enableOnSwitch,_that.enableOnListItem,_that.enableOnNavigation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  bool enableOnSidebar,  bool enableOnSwitch,  bool enableOnListItem,  bool enableOnNavigation)  $default,) {final _that = this;
switch (_that) {
case _HapticFeedbackSettings():
return $default(_that.enabled,_that.enableOnSidebar,_that.enableOnSwitch,_that.enableOnListItem,_that.enableOnNavigation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  bool enableOnSidebar,  bool enableOnSwitch,  bool enableOnListItem,  bool enableOnNavigation)?  $default,) {final _that = this;
switch (_that) {
case _HapticFeedbackSettings() when $default != null:
return $default(_that.enabled,_that.enableOnSidebar,_that.enableOnSwitch,_that.enableOnListItem,_that.enableOnNavigation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HapticFeedbackSettings implements HapticFeedbackSettings {
  const _HapticFeedbackSettings({this.enabled = true, this.enableOnSidebar = true, this.enableOnSwitch = true, this.enableOnListItem = false, this.enableOnNavigation = true});
  factory _HapticFeedbackSettings.fromJson(Map<String, dynamic> json) => _$HapticFeedbackSettingsFromJson(json);

@override@JsonKey() final  bool enabled;
@override@JsonKey() final  bool enableOnSidebar;
@override@JsonKey() final  bool enableOnSwitch;
@override@JsonKey() final  bool enableOnListItem;
@override@JsonKey() final  bool enableOnNavigation;

/// Create a copy of HapticFeedbackSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HapticFeedbackSettingsCopyWith<_HapticFeedbackSettings> get copyWith => __$HapticFeedbackSettingsCopyWithImpl<_HapticFeedbackSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HapticFeedbackSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HapticFeedbackSettings&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.enableOnSidebar, enableOnSidebar) || other.enableOnSidebar == enableOnSidebar)&&(identical(other.enableOnSwitch, enableOnSwitch) || other.enableOnSwitch == enableOnSwitch)&&(identical(other.enableOnListItem, enableOnListItem) || other.enableOnListItem == enableOnListItem)&&(identical(other.enableOnNavigation, enableOnNavigation) || other.enableOnNavigation == enableOnNavigation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,enableOnSidebar,enableOnSwitch,enableOnListItem,enableOnNavigation);

@override
String toString() {
  return 'HapticFeedbackSettings(enabled: $enabled, enableOnSidebar: $enableOnSidebar, enableOnSwitch: $enableOnSwitch, enableOnListItem: $enableOnListItem, enableOnNavigation: $enableOnNavigation)';
}


}

/// @nodoc
abstract mixin class _$HapticFeedbackSettingsCopyWith<$Res> implements $HapticFeedbackSettingsCopyWith<$Res> {
  factory _$HapticFeedbackSettingsCopyWith(_HapticFeedbackSettings value, $Res Function(_HapticFeedbackSettings) _then) = __$HapticFeedbackSettingsCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, bool enableOnSidebar, bool enableOnSwitch, bool enableOnListItem, bool enableOnNavigation
});




}
/// @nodoc
class __$HapticFeedbackSettingsCopyWithImpl<$Res>
    implements _$HapticFeedbackSettingsCopyWith<$Res> {
  __$HapticFeedbackSettingsCopyWithImpl(this._self, this._then);

  final _HapticFeedbackSettings _self;
  final $Res Function(_HapticFeedbackSettings) _then;

/// Create a copy of HapticFeedbackSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? enableOnSidebar = null,Object? enableOnSwitch = null,Object? enableOnListItem = null,Object? enableOnNavigation = null,}) {
  return _then(_HapticFeedbackSettings(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,enableOnSidebar: null == enableOnSidebar ? _self.enableOnSidebar : enableOnSidebar // ignore: cast_nullable_to_non_nullable
as bool,enableOnSwitch: null == enableOnSwitch ? _self.enableOnSwitch : enableOnSwitch // ignore: cast_nullable_to_non_nullable
as bool,enableOnListItem: null == enableOnListItem ? _self.enableOnListItem : enableOnListItem // ignore: cast_nullable_to_non_nullable
as bool,enableOnNavigation: null == enableOnNavigation ? _self.enableOnNavigation : enableOnNavigation // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$BehaviorSettings {

 bool get sendWithEnter; bool get enableNotifications; bool get mobileInputMethodEnterAsNewline; HapticFeedbackSettings get hapticFeedback;
/// Create a copy of BehaviorSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BehaviorSettingsCopyWith<BehaviorSettings> get copyWith => _$BehaviorSettingsCopyWithImpl<BehaviorSettings>(this as BehaviorSettings, _$identity);

  /// Serializes this BehaviorSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BehaviorSettings&&(identical(other.sendWithEnter, sendWithEnter) || other.sendWithEnter == sendWithEnter)&&(identical(other.enableNotifications, enableNotifications) || other.enableNotifications == enableNotifications)&&(identical(other.mobileInputMethodEnterAsNewline, mobileInputMethodEnterAsNewline) || other.mobileInputMethodEnterAsNewline == mobileInputMethodEnterAsNewline)&&(identical(other.hapticFeedback, hapticFeedback) || other.hapticFeedback == hapticFeedback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sendWithEnter,enableNotifications,mobileInputMethodEnterAsNewline,hapticFeedback);

@override
String toString() {
  return 'BehaviorSettings(sendWithEnter: $sendWithEnter, enableNotifications: $enableNotifications, mobileInputMethodEnterAsNewline: $mobileInputMethodEnterAsNewline, hapticFeedback: $hapticFeedback)';
}


}

/// @nodoc
abstract mixin class $BehaviorSettingsCopyWith<$Res>  {
  factory $BehaviorSettingsCopyWith(BehaviorSettings value, $Res Function(BehaviorSettings) _then) = _$BehaviorSettingsCopyWithImpl;
@useResult
$Res call({
 bool sendWithEnter, bool enableNotifications, bool mobileInputMethodEnterAsNewline, HapticFeedbackSettings hapticFeedback
});


$HapticFeedbackSettingsCopyWith<$Res> get hapticFeedback;

}
/// @nodoc
class _$BehaviorSettingsCopyWithImpl<$Res>
    implements $BehaviorSettingsCopyWith<$Res> {
  _$BehaviorSettingsCopyWithImpl(this._self, this._then);

  final BehaviorSettings _self;
  final $Res Function(BehaviorSettings) _then;

/// Create a copy of BehaviorSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sendWithEnter = null,Object? enableNotifications = null,Object? mobileInputMethodEnterAsNewline = null,Object? hapticFeedback = null,}) {
  return _then(_self.copyWith(
sendWithEnter: null == sendWithEnter ? _self.sendWithEnter : sendWithEnter // ignore: cast_nullable_to_non_nullable
as bool,enableNotifications: null == enableNotifications ? _self.enableNotifications : enableNotifications // ignore: cast_nullable_to_non_nullable
as bool,mobileInputMethodEnterAsNewline: null == mobileInputMethodEnterAsNewline ? _self.mobileInputMethodEnterAsNewline : mobileInputMethodEnterAsNewline // ignore: cast_nullable_to_non_nullable
as bool,hapticFeedback: null == hapticFeedback ? _self.hapticFeedback : hapticFeedback // ignore: cast_nullable_to_non_nullable
as HapticFeedbackSettings,
  ));
}
/// Create a copy of BehaviorSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HapticFeedbackSettingsCopyWith<$Res> get hapticFeedback {
  
  return $HapticFeedbackSettingsCopyWith<$Res>(_self.hapticFeedback, (value) {
    return _then(_self.copyWith(hapticFeedback: value));
  });
}
}


/// Adds pattern-matching-related methods to [BehaviorSettings].
extension BehaviorSettingsPatterns on BehaviorSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BehaviorSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BehaviorSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BehaviorSettings value)  $default,){
final _that = this;
switch (_that) {
case _BehaviorSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BehaviorSettings value)?  $default,){
final _that = this;
switch (_that) {
case _BehaviorSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool sendWithEnter,  bool enableNotifications,  bool mobileInputMethodEnterAsNewline,  HapticFeedbackSettings hapticFeedback)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BehaviorSettings() when $default != null:
return $default(_that.sendWithEnter,_that.enableNotifications,_that.mobileInputMethodEnterAsNewline,_that.hapticFeedback);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool sendWithEnter,  bool enableNotifications,  bool mobileInputMethodEnterAsNewline,  HapticFeedbackSettings hapticFeedback)  $default,) {final _that = this;
switch (_that) {
case _BehaviorSettings():
return $default(_that.sendWithEnter,_that.enableNotifications,_that.mobileInputMethodEnterAsNewline,_that.hapticFeedback);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool sendWithEnter,  bool enableNotifications,  bool mobileInputMethodEnterAsNewline,  HapticFeedbackSettings hapticFeedback)?  $default,) {final _that = this;
switch (_that) {
case _BehaviorSettings() when $default != null:
return $default(_that.sendWithEnter,_that.enableNotifications,_that.mobileInputMethodEnterAsNewline,_that.hapticFeedback);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BehaviorSettings implements BehaviorSettings {
  const _BehaviorSettings({this.sendWithEnter = true, this.enableNotifications = true, this.mobileInputMethodEnterAsNewline = false, this.hapticFeedback = const HapticFeedbackSettings()});
  factory _BehaviorSettings.fromJson(Map<String, dynamic> json) => _$BehaviorSettingsFromJson(json);

@override@JsonKey() final  bool sendWithEnter;
@override@JsonKey() final  bool enableNotifications;
@override@JsonKey() final  bool mobileInputMethodEnterAsNewline;
@override@JsonKey() final  HapticFeedbackSettings hapticFeedback;

/// Create a copy of BehaviorSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BehaviorSettingsCopyWith<_BehaviorSettings> get copyWith => __$BehaviorSettingsCopyWithImpl<_BehaviorSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BehaviorSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BehaviorSettings&&(identical(other.sendWithEnter, sendWithEnter) || other.sendWithEnter == sendWithEnter)&&(identical(other.enableNotifications, enableNotifications) || other.enableNotifications == enableNotifications)&&(identical(other.mobileInputMethodEnterAsNewline, mobileInputMethodEnterAsNewline) || other.mobileInputMethodEnterAsNewline == mobileInputMethodEnterAsNewline)&&(identical(other.hapticFeedback, hapticFeedback) || other.hapticFeedback == hapticFeedback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sendWithEnter,enableNotifications,mobileInputMethodEnterAsNewline,hapticFeedback);

@override
String toString() {
  return 'BehaviorSettings(sendWithEnter: $sendWithEnter, enableNotifications: $enableNotifications, mobileInputMethodEnterAsNewline: $mobileInputMethodEnterAsNewline, hapticFeedback: $hapticFeedback)';
}


}

/// @nodoc
abstract mixin class _$BehaviorSettingsCopyWith<$Res> implements $BehaviorSettingsCopyWith<$Res> {
  factory _$BehaviorSettingsCopyWith(_BehaviorSettings value, $Res Function(_BehaviorSettings) _then) = __$BehaviorSettingsCopyWithImpl;
@override @useResult
$Res call({
 bool sendWithEnter, bool enableNotifications, bool mobileInputMethodEnterAsNewline, HapticFeedbackSettings hapticFeedback
});


@override $HapticFeedbackSettingsCopyWith<$Res> get hapticFeedback;

}
/// @nodoc
class __$BehaviorSettingsCopyWithImpl<$Res>
    implements _$BehaviorSettingsCopyWith<$Res> {
  __$BehaviorSettingsCopyWithImpl(this._self, this._then);

  final _BehaviorSettings _self;
  final $Res Function(_BehaviorSettings) _then;

/// Create a copy of BehaviorSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sendWithEnter = null,Object? enableNotifications = null,Object? mobileInputMethodEnterAsNewline = null,Object? hapticFeedback = null,}) {
  return _then(_BehaviorSettings(
sendWithEnter: null == sendWithEnter ? _self.sendWithEnter : sendWithEnter // ignore: cast_nullable_to_non_nullable
as bool,enableNotifications: null == enableNotifications ? _self.enableNotifications : enableNotifications // ignore: cast_nullable_to_non_nullable
as bool,mobileInputMethodEnterAsNewline: null == mobileInputMethodEnterAsNewline ? _self.mobileInputMethodEnterAsNewline : mobileInputMethodEnterAsNewline // ignore: cast_nullable_to_non_nullable
as bool,hapticFeedback: null == hapticFeedback ? _self.hapticFeedback : hapticFeedback // ignore: cast_nullable_to_non_nullable
as HapticFeedbackSettings,
  ));
}

/// Create a copy of BehaviorSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HapticFeedbackSettingsCopyWith<$Res> get hapticFeedback {
  
  return $HapticFeedbackSettingsCopyWith<$Res>(_self.hapticFeedback, (value) {
    return _then(_self.copyWith(hapticFeedback: value));
  });
}
}

// dart format on
