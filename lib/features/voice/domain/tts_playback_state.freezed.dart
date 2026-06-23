// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tts_playback_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TtsPlaybackState {

 TtsStatus get status;/// The message ID whose content is being spoken.
 String? get messageId;/// Which provider is currently active.
 TtsProviderKind? get activeProvider;/// Current chunk index (0-based).
 int get currentChunk;/// Total number of chunks.
 int get totalChunks;/// Playback speed multiplier.
 double get speed;/// Error description when [status] is [TtsStatus.error].
 String? get error;
/// Create a copy of TtsPlaybackState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TtsPlaybackStateCopyWith<TtsPlaybackState> get copyWith => _$TtsPlaybackStateCopyWithImpl<TtsPlaybackState>(this as TtsPlaybackState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsPlaybackState&&(identical(other.status, status) || other.status == status)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.activeProvider, activeProvider) || other.activeProvider == activeProvider)&&(identical(other.currentChunk, currentChunk) || other.currentChunk == currentChunk)&&(identical(other.totalChunks, totalChunks) || other.totalChunks == totalChunks)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,status,messageId,activeProvider,currentChunk,totalChunks,speed,error);

@override
String toString() {
  return 'TtsPlaybackState(status: $status, messageId: $messageId, activeProvider: $activeProvider, currentChunk: $currentChunk, totalChunks: $totalChunks, speed: $speed, error: $error)';
}


}

/// @nodoc
abstract mixin class $TtsPlaybackStateCopyWith<$Res>  {
  factory $TtsPlaybackStateCopyWith(TtsPlaybackState value, $Res Function(TtsPlaybackState) _then) = _$TtsPlaybackStateCopyWithImpl;
@useResult
$Res call({
 TtsStatus status, String? messageId, TtsProviderKind? activeProvider, int currentChunk, int totalChunks, double speed, String? error
});




}
/// @nodoc
class _$TtsPlaybackStateCopyWithImpl<$Res>
    implements $TtsPlaybackStateCopyWith<$Res> {
  _$TtsPlaybackStateCopyWithImpl(this._self, this._then);

  final TtsPlaybackState _self;
  final $Res Function(TtsPlaybackState) _then;

/// Create a copy of TtsPlaybackState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? messageId = freezed,Object? activeProvider = freezed,Object? currentChunk = null,Object? totalChunks = null,Object? speed = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TtsStatus,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,activeProvider: freezed == activeProvider ? _self.activeProvider : activeProvider // ignore: cast_nullable_to_non_nullable
as TtsProviderKind?,currentChunk: null == currentChunk ? _self.currentChunk : currentChunk // ignore: cast_nullable_to_non_nullable
as int,totalChunks: null == totalChunks ? _self.totalChunks : totalChunks // ignore: cast_nullable_to_non_nullable
as int,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TtsPlaybackState].
extension TtsPlaybackStatePatterns on TtsPlaybackState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TtsPlaybackState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TtsPlaybackState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TtsPlaybackState value)  $default,){
final _that = this;
switch (_that) {
case _TtsPlaybackState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TtsPlaybackState value)?  $default,){
final _that = this;
switch (_that) {
case _TtsPlaybackState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TtsStatus status,  String? messageId,  TtsProviderKind? activeProvider,  int currentChunk,  int totalChunks,  double speed,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TtsPlaybackState() when $default != null:
return $default(_that.status,_that.messageId,_that.activeProvider,_that.currentChunk,_that.totalChunks,_that.speed,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TtsStatus status,  String? messageId,  TtsProviderKind? activeProvider,  int currentChunk,  int totalChunks,  double speed,  String? error)  $default,) {final _that = this;
switch (_that) {
case _TtsPlaybackState():
return $default(_that.status,_that.messageId,_that.activeProvider,_that.currentChunk,_that.totalChunks,_that.speed,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TtsStatus status,  String? messageId,  TtsProviderKind? activeProvider,  int currentChunk,  int totalChunks,  double speed,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _TtsPlaybackState() when $default != null:
return $default(_that.status,_that.messageId,_that.activeProvider,_that.currentChunk,_that.totalChunks,_that.speed,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _TtsPlaybackState implements TtsPlaybackState {
  const _TtsPlaybackState({this.status = TtsStatus.idle, this.messageId, this.activeProvider, this.currentChunk = 0, this.totalChunks = 0, this.speed = 1.0, this.error});
  

@override@JsonKey() final  TtsStatus status;
/// The message ID whose content is being spoken.
@override final  String? messageId;
/// Which provider is currently active.
@override final  TtsProviderKind? activeProvider;
/// Current chunk index (0-based).
@override@JsonKey() final  int currentChunk;
/// Total number of chunks.
@override@JsonKey() final  int totalChunks;
/// Playback speed multiplier.
@override@JsonKey() final  double speed;
/// Error description when [status] is [TtsStatus.error].
@override final  String? error;

/// Create a copy of TtsPlaybackState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TtsPlaybackStateCopyWith<_TtsPlaybackState> get copyWith => __$TtsPlaybackStateCopyWithImpl<_TtsPlaybackState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TtsPlaybackState&&(identical(other.status, status) || other.status == status)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.activeProvider, activeProvider) || other.activeProvider == activeProvider)&&(identical(other.currentChunk, currentChunk) || other.currentChunk == currentChunk)&&(identical(other.totalChunks, totalChunks) || other.totalChunks == totalChunks)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,status,messageId,activeProvider,currentChunk,totalChunks,speed,error);

@override
String toString() {
  return 'TtsPlaybackState(status: $status, messageId: $messageId, activeProvider: $activeProvider, currentChunk: $currentChunk, totalChunks: $totalChunks, speed: $speed, error: $error)';
}


}

/// @nodoc
abstract mixin class _$TtsPlaybackStateCopyWith<$Res> implements $TtsPlaybackStateCopyWith<$Res> {
  factory _$TtsPlaybackStateCopyWith(_TtsPlaybackState value, $Res Function(_TtsPlaybackState) _then) = __$TtsPlaybackStateCopyWithImpl;
@override @useResult
$Res call({
 TtsStatus status, String? messageId, TtsProviderKind? activeProvider, int currentChunk, int totalChunks, double speed, String? error
});




}
/// @nodoc
class __$TtsPlaybackStateCopyWithImpl<$Res>
    implements _$TtsPlaybackStateCopyWith<$Res> {
  __$TtsPlaybackStateCopyWithImpl(this._self, this._then);

  final _TtsPlaybackState _self;
  final $Res Function(_TtsPlaybackState) _then;

/// Create a copy of TtsPlaybackState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? messageId = freezed,Object? activeProvider = freezed,Object? currentChunk = null,Object? totalChunks = null,Object? speed = null,Object? error = freezed,}) {
  return _then(_TtsPlaybackState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TtsStatus,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,activeProvider: freezed == activeProvider ? _self.activeProvider : activeProvider // ignore: cast_nullable_to_non_nullable
as TtsProviderKind?,currentChunk: null == currentChunk ? _self.currentChunk : currentChunk // ignore: cast_nullable_to_non_nullable
as int,totalChunks: null == totalChunks ? _self.totalChunks : totalChunks // ignore: cast_nullable_to_non_nullable
as int,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
