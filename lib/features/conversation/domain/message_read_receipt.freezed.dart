// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_read_receipt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MemberReadReceipt {

 String get membershipId; String get userId; String get nickname; ConversationReadStatus get status;
/// Create a copy of MemberReadReceipt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MemberReadReceiptCopyWith<MemberReadReceipt> get copyWith => _$MemberReadReceiptCopyWithImpl<MemberReadReceipt>(this as MemberReadReceipt, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MemberReadReceipt;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MemberReadReceipt&&(identical(other.membershipId, _this.membershipId) || other.membershipId == _this.membershipId)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.nickname, _this.nickname) || other.nickname == _this.nickname)&&(identical(other.status, _this.status) || other.status == _this.status));
}


@override
int get hashCode {
  final _this = this as MemberReadReceipt;
  return Object.hash(runtimeType,_this.membershipId,_this.userId,_this.nickname,_this.status);
}

@override
String toString() {
  final _this = this as MemberReadReceipt;
  return 'MemberReadReceipt(membershipId: ${_this.membershipId}, userId: ${_this.userId}, nickname: ${_this.nickname}, status: ${_this.status})';
}


}

/// @nodoc
abstract mixin class $MemberReadReceiptCopyWith<$Res>  {
  factory $MemberReadReceiptCopyWith(MemberReadReceipt value, $Res Function(MemberReadReceipt) _then) = _$MemberReadReceiptCopyWithImpl;
@useResult
$Res call({
 String membershipId, String userId, String nickname, ConversationReadStatus status
});




}
/// @nodoc
class _$MemberReadReceiptCopyWithImpl<$Res>
    implements $MemberReadReceiptCopyWith<$Res> {
  _$MemberReadReceiptCopyWithImpl(this._self, this._then);

  final MemberReadReceipt _self;
  final $Res Function(MemberReadReceipt) _then;

/// Create a copy of MemberReadReceipt
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? membershipId = null,Object? userId = null,Object? nickname = null,Object? status = null,}) {
  return _then(MemberReadReceipt(
membershipId: null == membershipId ? _self.membershipId : membershipId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ConversationReadStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [MemberReadReceipt].
extension MemberReadReceiptPatterns on MemberReadReceipt {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MemberReadReceipt value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MemberReadReceipt() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MemberReadReceipt value)  $default,){
final _that = this;
switch (_that) {
case _MemberReadReceipt():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MemberReadReceipt value)?  $default,){
final _that = this;
switch (_that) {
case _MemberReadReceipt() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String membershipId,  String userId,  String nickname,  ConversationReadStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MemberReadReceipt() when $default != null:
return $default(_that.membershipId,_that.userId,_that.nickname,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String membershipId,  String userId,  String nickname,  ConversationReadStatus status)  $default,) {final _that = this;
switch (_that) {
case _MemberReadReceipt():
return $default(_that.membershipId,_that.userId,_that.nickname,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String membershipId,  String userId,  String nickname,  ConversationReadStatus status)?  $default,) {final _that = this;
switch (_that) {
case _MemberReadReceipt() when $default != null:
return $default(_that.membershipId,_that.userId,_that.nickname,_that.status);case _:
  return null;

}
}

}

/// @nodoc


class _MemberReadReceipt implements MemberReadReceipt {
  const _MemberReadReceipt({required this.membershipId, required this.userId, required this.nickname, required this.status});
  

@override final  String membershipId;
@override final  String userId;
@override final  String nickname;
@override final  ConversationReadStatus status;

/// Create a copy of MemberReadReceipt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MemberReadReceiptCopyWith<_MemberReadReceipt> get copyWith => __$MemberReadReceiptCopyWithImpl<_MemberReadReceipt>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MemberReadReceipt&&(identical(other.membershipId, membershipId) || other.membershipId == membershipId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode {
    return Object.hash(runtimeType,membershipId,userId,nickname,status);
}

@override
String toString() {
    return 'MemberReadReceipt(membershipId: $membershipId, userId: $userId, nickname: $nickname, status: $status)';
}


}

/// @nodoc
abstract mixin class _$MemberReadReceiptCopyWith<$Res> implements $MemberReadReceiptCopyWith<$Res> {
  factory _$MemberReadReceiptCopyWith(_MemberReadReceipt value, $Res Function(_MemberReadReceipt) _then) = __$MemberReadReceiptCopyWithImpl;
@override @useResult
$Res call({
 String membershipId, String userId, String nickname, ConversationReadStatus status
});




}
/// @nodoc
class __$MemberReadReceiptCopyWithImpl<$Res>
    implements _$MemberReadReceiptCopyWith<$Res> {
  __$MemberReadReceiptCopyWithImpl(this._self, this._then);

  final _MemberReadReceipt _self;
  final $Res Function(_MemberReadReceipt) _then;

/// Create a copy of MemberReadReceipt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? membershipId = null,Object? userId = null,Object? nickname = null,Object? status = null,}) {
  return _then(_MemberReadReceipt(
membershipId: null == membershipId ? _self.membershipId : membershipId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ConversationReadStatus,
  ));
}


}

/// @nodoc
mixin _$MessageReadReceipt {

 String get messageId; List<MemberReadReceipt> get members;
/// Create a copy of MessageReadReceipt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageReadReceiptCopyWith<MessageReadReceipt> get copyWith => _$MessageReadReceiptCopyWithImpl<MessageReadReceipt>(this as MessageReadReceipt, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MessageReadReceipt;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageReadReceipt&&(identical(other.messageId, _this.messageId) || other.messageId == _this.messageId)&&const DeepCollectionEquality().equals(other.members, _this.members));
}


@override
int get hashCode {
  final _this = this as MessageReadReceipt;
  return Object.hash(runtimeType,_this.messageId,const DeepCollectionEquality().hash(_this.members));
}

@override
String toString() {
  final _this = this as MessageReadReceipt;
  return 'MessageReadReceipt(messageId: ${_this.messageId}, members: ${_this.members})';
}


}

/// @nodoc
abstract mixin class $MessageReadReceiptCopyWith<$Res>  {
  factory $MessageReadReceiptCopyWith(MessageReadReceipt value, $Res Function(MessageReadReceipt) _then) = _$MessageReadReceiptCopyWithImpl;
@useResult
$Res call({
 String messageId, List<MemberReadReceipt> members
});




}
/// @nodoc
class _$MessageReadReceiptCopyWithImpl<$Res>
    implements $MessageReadReceiptCopyWith<$Res> {
  _$MessageReadReceiptCopyWithImpl(this._self, this._then);

  final MessageReadReceipt _self;
  final $Res Function(MessageReadReceipt) _then;

/// Create a copy of MessageReadReceipt
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? members = null,}) {
  return _then(MessageReadReceipt(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<MemberReadReceipt>,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageReadReceipt].
extension MessageReadReceiptPatterns on MessageReadReceipt {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageReadReceipt value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageReadReceipt() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageReadReceipt value)  $default,){
final _that = this;
switch (_that) {
case _MessageReadReceipt():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageReadReceipt value)?  $default,){
final _that = this;
switch (_that) {
case _MessageReadReceipt() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId,  List<MemberReadReceipt> members)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageReadReceipt() when $default != null:
return $default(_that.messageId,_that.members);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId,  List<MemberReadReceipt> members)  $default,) {final _that = this;
switch (_that) {
case _MessageReadReceipt():
return $default(_that.messageId,_that.members);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId,  List<MemberReadReceipt> members)?  $default,) {final _that = this;
switch (_that) {
case _MessageReadReceipt() when $default != null:
return $default(_that.messageId,_that.members);case _:
  return null;

}
}

}

/// @nodoc


class _MessageReadReceipt extends MessageReadReceipt {
  const _MessageReadReceipt({required this.messageId, required  List<MemberReadReceipt> members}): _members = members,super._();
  

@override final  String messageId;
 final  List<MemberReadReceipt> _members;
@override List<MemberReadReceipt> get members {
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_members);
}


/// Create a copy of MessageReadReceipt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageReadReceiptCopyWith<_MessageReadReceipt> get copyWith => __$MessageReadReceiptCopyWithImpl<_MessageReadReceipt>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageReadReceipt&&(identical(other.messageId, messageId) || other.messageId == messageId)&&const DeepCollectionEquality().equals(other.members, _members));
}


@override
int get hashCode {
    return Object.hash(runtimeType,messageId,const DeepCollectionEquality().hash(_members));
}

@override
String toString() {
    return 'MessageReadReceipt(messageId: $messageId, members: $members)';
}


}

/// @nodoc
abstract mixin class _$MessageReadReceiptCopyWith<$Res> implements $MessageReadReceiptCopyWith<$Res> {
  factory _$MessageReadReceiptCopyWith(_MessageReadReceipt value, $Res Function(_MessageReadReceipt) _then) = __$MessageReadReceiptCopyWithImpl;
@override @useResult
$Res call({
 String messageId, List<MemberReadReceipt> members
});




}
/// @nodoc
class __$MessageReadReceiptCopyWithImpl<$Res>
    implements _$MessageReadReceiptCopyWith<$Res> {
  __$MessageReadReceiptCopyWithImpl(this._self, this._then);

  final _MessageReadReceipt _self;
  final $Res Function(_MessageReadReceipt) _then;

/// Create a copy of MessageReadReceipt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? members = null,}) {
  return _then(_MessageReadReceipt(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<MemberReadReceipt>,
  ));
}


}

// dart format on
