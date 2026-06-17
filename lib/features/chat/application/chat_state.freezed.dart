// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatMessageView {

 String get id; MessageRole get role; MessageStatus get status; List<MessageBlock> get blocks; String get text; String get thinking; String? get errorText; DateTime? get createdAt; String? get modelName; String? get providerName; List<MessageVersion> get versions; String? get currentVersionId;
/// Create a copy of ChatMessageView
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatMessageViewCopyWith<ChatMessageView> get copyWith => _$ChatMessageViewCopyWithImpl<ChatMessageView>(this as ChatMessageView, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatMessageView&&(identical(other.id, id) || other.id == id)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.blocks, blocks)&&(identical(other.text, text) || other.text == text)&&(identical(other.thinking, thinking) || other.thinking == thinking)&&(identical(other.errorText, errorText) || other.errorText == errorText)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modelName, modelName) || other.modelName == modelName)&&(identical(other.providerName, providerName) || other.providerName == providerName)&&const DeepCollectionEquality().equals(other.versions, versions)&&(identical(other.currentVersionId, currentVersionId) || other.currentVersionId == currentVersionId));
}


@override
int get hashCode => Object.hash(runtimeType,id,role,status,const DeepCollectionEquality().hash(blocks),text,thinking,errorText,createdAt,modelName,providerName,const DeepCollectionEquality().hash(versions),currentVersionId);

@override
String toString() {
  return 'ChatMessageView(id: $id, role: $role, status: $status, blocks: $blocks, text: $text, thinking: $thinking, errorText: $errorText, createdAt: $createdAt, modelName: $modelName, providerName: $providerName, versions: $versions, currentVersionId: $currentVersionId)';
}


}

/// @nodoc
abstract mixin class $ChatMessageViewCopyWith<$Res>  {
  factory $ChatMessageViewCopyWith(ChatMessageView value, $Res Function(ChatMessageView) _then) = _$ChatMessageViewCopyWithImpl;
@useResult
$Res call({
 String id, MessageRole role, MessageStatus status, List<MessageBlock> blocks, String text, String thinking, String? errorText, DateTime? createdAt, String? modelName, String? providerName, List<MessageVersion> versions, String? currentVersionId
});




}
/// @nodoc
class _$ChatMessageViewCopyWithImpl<$Res>
    implements $ChatMessageViewCopyWith<$Res> {
  _$ChatMessageViewCopyWithImpl(this._self, this._then);

  final ChatMessageView _self;
  final $Res Function(ChatMessageView) _then;

/// Create a copy of ChatMessageView
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? role = null,Object? status = null,Object? blocks = null,Object? text = null,Object? thinking = null,Object? errorText = freezed,Object? createdAt = freezed,Object? modelName = freezed,Object? providerName = freezed,Object? versions = null,Object? currentVersionId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MessageRole,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,blocks: null == blocks ? _self.blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<MessageBlock>,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,thinking: null == thinking ? _self.thinking : thinking // ignore: cast_nullable_to_non_nullable
as String,errorText: freezed == errorText ? _self.errorText : errorText // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,modelName: freezed == modelName ? _self.modelName : modelName // ignore: cast_nullable_to_non_nullable
as String?,providerName: freezed == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String?,versions: null == versions ? _self.versions : versions // ignore: cast_nullable_to_non_nullable
as List<MessageVersion>,currentVersionId: freezed == currentVersionId ? _self.currentVersionId : currentVersionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatMessageView].
extension ChatMessageViewPatterns on ChatMessageView {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatMessageView value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatMessageView() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatMessageView value)  $default,){
final _that = this;
switch (_that) {
case _ChatMessageView():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatMessageView value)?  $default,){
final _that = this;
switch (_that) {
case _ChatMessageView() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  MessageRole role,  MessageStatus status,  List<MessageBlock> blocks,  String text,  String thinking,  String? errorText,  DateTime? createdAt,  String? modelName,  String? providerName,  List<MessageVersion> versions,  String? currentVersionId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatMessageView() when $default != null:
return $default(_that.id,_that.role,_that.status,_that.blocks,_that.text,_that.thinking,_that.errorText,_that.createdAt,_that.modelName,_that.providerName,_that.versions,_that.currentVersionId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  MessageRole role,  MessageStatus status,  List<MessageBlock> blocks,  String text,  String thinking,  String? errorText,  DateTime? createdAt,  String? modelName,  String? providerName,  List<MessageVersion> versions,  String? currentVersionId)  $default,) {final _that = this;
switch (_that) {
case _ChatMessageView():
return $default(_that.id,_that.role,_that.status,_that.blocks,_that.text,_that.thinking,_that.errorText,_that.createdAt,_that.modelName,_that.providerName,_that.versions,_that.currentVersionId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  MessageRole role,  MessageStatus status,  List<MessageBlock> blocks,  String text,  String thinking,  String? errorText,  DateTime? createdAt,  String? modelName,  String? providerName,  List<MessageVersion> versions,  String? currentVersionId)?  $default,) {final _that = this;
switch (_that) {
case _ChatMessageView() when $default != null:
return $default(_that.id,_that.role,_that.status,_that.blocks,_that.text,_that.thinking,_that.errorText,_that.createdAt,_that.modelName,_that.providerName,_that.versions,_that.currentVersionId);case _:
  return null;

}
}

}

/// @nodoc


class _ChatMessageView implements ChatMessageView {
  const _ChatMessageView({required this.id, required this.role, required this.status, final  List<MessageBlock> blocks = const <MessageBlock>[], this.text = '', this.thinking = '', this.errorText, this.createdAt, this.modelName, this.providerName, final  List<MessageVersion> versions = const <MessageVersion>[], this.currentVersionId}): _blocks = blocks,_versions = versions;
  

@override final  String id;
@override final  MessageRole role;
@override final  MessageStatus status;
 final  List<MessageBlock> _blocks;
@override@JsonKey() List<MessageBlock> get blocks {
  if (_blocks is EqualUnmodifiableListView) return _blocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blocks);
}

@override@JsonKey() final  String text;
@override@JsonKey() final  String thinking;
@override final  String? errorText;
@override final  DateTime? createdAt;
@override final  String? modelName;
@override final  String? providerName;
 final  List<MessageVersion> _versions;
@override@JsonKey() List<MessageVersion> get versions {
  if (_versions is EqualUnmodifiableListView) return _versions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_versions);
}

@override final  String? currentVersionId;

/// Create a copy of ChatMessageView
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatMessageViewCopyWith<_ChatMessageView> get copyWith => __$ChatMessageViewCopyWithImpl<_ChatMessageView>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatMessageView&&(identical(other.id, id) || other.id == id)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._blocks, _blocks)&&(identical(other.text, text) || other.text == text)&&(identical(other.thinking, thinking) || other.thinking == thinking)&&(identical(other.errorText, errorText) || other.errorText == errorText)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modelName, modelName) || other.modelName == modelName)&&(identical(other.providerName, providerName) || other.providerName == providerName)&&const DeepCollectionEquality().equals(other._versions, _versions)&&(identical(other.currentVersionId, currentVersionId) || other.currentVersionId == currentVersionId));
}


@override
int get hashCode => Object.hash(runtimeType,id,role,status,const DeepCollectionEquality().hash(_blocks),text,thinking,errorText,createdAt,modelName,providerName,const DeepCollectionEquality().hash(_versions),currentVersionId);

@override
String toString() {
  return 'ChatMessageView(id: $id, role: $role, status: $status, blocks: $blocks, text: $text, thinking: $thinking, errorText: $errorText, createdAt: $createdAt, modelName: $modelName, providerName: $providerName, versions: $versions, currentVersionId: $currentVersionId)';
}


}

/// @nodoc
abstract mixin class _$ChatMessageViewCopyWith<$Res> implements $ChatMessageViewCopyWith<$Res> {
  factory _$ChatMessageViewCopyWith(_ChatMessageView value, $Res Function(_ChatMessageView) _then) = __$ChatMessageViewCopyWithImpl;
@override @useResult
$Res call({
 String id, MessageRole role, MessageStatus status, List<MessageBlock> blocks, String text, String thinking, String? errorText, DateTime? createdAt, String? modelName, String? providerName, List<MessageVersion> versions, String? currentVersionId
});




}
/// @nodoc
class __$ChatMessageViewCopyWithImpl<$Res>
    implements _$ChatMessageViewCopyWith<$Res> {
  __$ChatMessageViewCopyWithImpl(this._self, this._then);

  final _ChatMessageView _self;
  final $Res Function(_ChatMessageView) _then;

/// Create a copy of ChatMessageView
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? role = null,Object? status = null,Object? blocks = null,Object? text = null,Object? thinking = null,Object? errorText = freezed,Object? createdAt = freezed,Object? modelName = freezed,Object? providerName = freezed,Object? versions = null,Object? currentVersionId = freezed,}) {
  return _then(_ChatMessageView(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MessageRole,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,blocks: null == blocks ? _self._blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<MessageBlock>,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,thinking: null == thinking ? _self.thinking : thinking // ignore: cast_nullable_to_non_nullable
as String,errorText: freezed == errorText ? _self.errorText : errorText // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,modelName: freezed == modelName ? _self.modelName : modelName // ignore: cast_nullable_to_non_nullable
as String?,providerName: freezed == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String?,versions: null == versions ? _self._versions : versions // ignore: cast_nullable_to_non_nullable
as List<MessageVersion>,currentVersionId: freezed == currentVersionId ? _self.currentVersionId : currentVersionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$ChatState {

 List<ChatMessageView> get messages; bool get isStreaming;
/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatStateCopyWith<ChatState> get copyWith => _$ChatStateCopyWithImpl<ChatState>(this as ChatState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatState&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.isStreaming, isStreaming) || other.isStreaming == isStreaming));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(messages),isStreaming);

@override
String toString() {
  return 'ChatState(messages: $messages, isStreaming: $isStreaming)';
}


}

/// @nodoc
abstract mixin class $ChatStateCopyWith<$Res>  {
  factory $ChatStateCopyWith(ChatState value, $Res Function(ChatState) _then) = _$ChatStateCopyWithImpl;
@useResult
$Res call({
 List<ChatMessageView> messages, bool isStreaming
});




}
/// @nodoc
class _$ChatStateCopyWithImpl<$Res>
    implements $ChatStateCopyWith<$Res> {
  _$ChatStateCopyWithImpl(this._self, this._then);

  final ChatState _self;
  final $Res Function(ChatState) _then;

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messages = null,Object? isStreaming = null,}) {
  return _then(_self.copyWith(
messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<ChatMessageView>,isStreaming: null == isStreaming ? _self.isStreaming : isStreaming // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatState].
extension ChatStatePatterns on ChatState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatState value)  $default,){
final _that = this;
switch (_that) {
case _ChatState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ChatMessageView> messages,  bool isStreaming)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatState() when $default != null:
return $default(_that.messages,_that.isStreaming);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ChatMessageView> messages,  bool isStreaming)  $default,) {final _that = this;
switch (_that) {
case _ChatState():
return $default(_that.messages,_that.isStreaming);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ChatMessageView> messages,  bool isStreaming)?  $default,) {final _that = this;
switch (_that) {
case _ChatState() when $default != null:
return $default(_that.messages,_that.isStreaming);case _:
  return null;

}
}

}

/// @nodoc


class _ChatState extends ChatState {
  const _ChatState({final  List<ChatMessageView> messages = const <ChatMessageView>[], this.isStreaming = false}): _messages = messages,super._();
  

 final  List<ChatMessageView> _messages;
@override@JsonKey() List<ChatMessageView> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

@override@JsonKey() final  bool isStreaming;

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatStateCopyWith<_ChatState> get copyWith => __$ChatStateCopyWithImpl<_ChatState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatState&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.isStreaming, isStreaming) || other.isStreaming == isStreaming));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_messages),isStreaming);

@override
String toString() {
  return 'ChatState(messages: $messages, isStreaming: $isStreaming)';
}


}

/// @nodoc
abstract mixin class _$ChatStateCopyWith<$Res> implements $ChatStateCopyWith<$Res> {
  factory _$ChatStateCopyWith(_ChatState value, $Res Function(_ChatState) _then) = __$ChatStateCopyWithImpl;
@override @useResult
$Res call({
 List<ChatMessageView> messages, bool isStreaming
});




}
/// @nodoc
class __$ChatStateCopyWithImpl<$Res>
    implements _$ChatStateCopyWith<$Res> {
  __$ChatStateCopyWithImpl(this._self, this._then);

  final _ChatState _self;
  final $Res Function(_ChatState) _then;

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messages = null,Object? isStreaming = null,}) {
  return _then(_ChatState(
messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<ChatMessageView>,isStreaming: null == isStreaming ? _self.isStreaming : isStreaming // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
