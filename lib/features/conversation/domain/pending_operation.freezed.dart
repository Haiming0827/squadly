// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pending_operation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PendingConversationOperation {

 String get userId; String get squadId; String get clientNonce; DateTime get createdAt;
/// Create a copy of PendingConversationOperation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingConversationOperationCopyWith<PendingConversationOperation> get copyWith => _$PendingConversationOperationCopyWithImpl<PendingConversationOperation>(this as PendingConversationOperation, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingConversationOperation&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.clientNonce, clientNonce) || other.clientNonce == clientNonce)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,userId,squadId,clientNonce,createdAt);

@override
String toString() {
  return 'PendingConversationOperation(userId: $userId, squadId: $squadId, clientNonce: $clientNonce, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PendingConversationOperationCopyWith<$Res>  {
  factory $PendingConversationOperationCopyWith(PendingConversationOperation value, $Res Function(PendingConversationOperation) _then) = _$PendingConversationOperationCopyWithImpl;
@useResult
$Res call({
 String userId, String squadId, String clientNonce, DateTime createdAt
});




}
/// @nodoc
class _$PendingConversationOperationCopyWithImpl<$Res>
    implements $PendingConversationOperationCopyWith<$Res> {
  _$PendingConversationOperationCopyWithImpl(this._self, this._then);

  final PendingConversationOperation _self;
  final $Res Function(PendingConversationOperation) _then;

/// Create a copy of PendingConversationOperation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? squadId = null,Object? clientNonce = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,clientNonce: null == clientNonce ? _self.clientNonce : clientNonce // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [PendingConversationOperation].
extension PendingConversationOperationPatterns on PendingConversationOperation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PendingTextOperation value)?  text,TResult Function( PendingCardOperation value)?  card,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PendingTextOperation() when text != null:
return text(_that);case PendingCardOperation() when card != null:
return card(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PendingTextOperation value)  text,required TResult Function( PendingCardOperation value)  card,}){
final _that = this;
switch (_that) {
case PendingTextOperation():
return text(_that);case PendingCardOperation():
return card(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PendingTextOperation value)?  text,TResult? Function( PendingCardOperation value)?  card,}){
final _that = this;
switch (_that) {
case PendingTextOperation() when text != null:
return text(_that);case PendingCardOperation() when card != null:
return card(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String userId,  String squadId,  String clientNonce,  DateTime createdAt,  String body,  String? replyToEntryId)?  text,TResult Function( String userId,  String squadId,  String clientNonce,  DateTime createdAt,  String cardId,  CardSnapshot snapshot,  EncryptedRouteBundle? encryptedRoute)?  card,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PendingTextOperation() when text != null:
return text(_that.userId,_that.squadId,_that.clientNonce,_that.createdAt,_that.body,_that.replyToEntryId);case PendingCardOperation() when card != null:
return card(_that.userId,_that.squadId,_that.clientNonce,_that.createdAt,_that.cardId,_that.snapshot,_that.encryptedRoute);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String userId,  String squadId,  String clientNonce,  DateTime createdAt,  String body,  String? replyToEntryId)  text,required TResult Function( String userId,  String squadId,  String clientNonce,  DateTime createdAt,  String cardId,  CardSnapshot snapshot,  EncryptedRouteBundle? encryptedRoute)  card,}) {final _that = this;
switch (_that) {
case PendingTextOperation():
return text(_that.userId,_that.squadId,_that.clientNonce,_that.createdAt,_that.body,_that.replyToEntryId);case PendingCardOperation():
return card(_that.userId,_that.squadId,_that.clientNonce,_that.createdAt,_that.cardId,_that.snapshot,_that.encryptedRoute);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String userId,  String squadId,  String clientNonce,  DateTime createdAt,  String body,  String? replyToEntryId)?  text,TResult? Function( String userId,  String squadId,  String clientNonce,  DateTime createdAt,  String cardId,  CardSnapshot snapshot,  EncryptedRouteBundle? encryptedRoute)?  card,}) {final _that = this;
switch (_that) {
case PendingTextOperation() when text != null:
return text(_that.userId,_that.squadId,_that.clientNonce,_that.createdAt,_that.body,_that.replyToEntryId);case PendingCardOperation() when card != null:
return card(_that.userId,_that.squadId,_that.clientNonce,_that.createdAt,_that.cardId,_that.snapshot,_that.encryptedRoute);case _:
  return null;

}
}

}

/// @nodoc


class PendingTextOperation implements PendingConversationOperation {
  const PendingTextOperation({required this.userId, required this.squadId, required this.clientNonce, required this.createdAt, required this.body, this.replyToEntryId});


@override final  String userId;
@override final  String squadId;
@override final  String clientNonce;
@override final  DateTime createdAt;
 final  String body;
 final  String? replyToEntryId;

/// Create a copy of PendingConversationOperation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingTextOperationCopyWith<PendingTextOperation> get copyWith => _$PendingTextOperationCopyWithImpl<PendingTextOperation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingTextOperation&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.clientNonce, clientNonce) || other.clientNonce == clientNonce)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.body, body) || other.body == body)&&(identical(other.replyToEntryId, replyToEntryId) || other.replyToEntryId == replyToEntryId));
}


@override
int get hashCode => Object.hash(runtimeType,userId,squadId,clientNonce,createdAt,body,replyToEntryId);

@override
String toString() {
  return 'PendingConversationOperation.text(userId: $userId, squadId: $squadId, clientNonce: $clientNonce, createdAt: $createdAt, body: $body, replyToEntryId: $replyToEntryId)';
}


}

/// @nodoc
abstract mixin class $PendingTextOperationCopyWith<$Res> implements $PendingConversationOperationCopyWith<$Res> {
  factory $PendingTextOperationCopyWith(PendingTextOperation value, $Res Function(PendingTextOperation) _then) = _$PendingTextOperationCopyWithImpl;
@override @useResult
$Res call({
 String userId, String squadId, String clientNonce, DateTime createdAt, String body, String? replyToEntryId
});




}
/// @nodoc
class _$PendingTextOperationCopyWithImpl<$Res>
    implements $PendingTextOperationCopyWith<$Res> {
  _$PendingTextOperationCopyWithImpl(this._self, this._then);

  final PendingTextOperation _self;
  final $Res Function(PendingTextOperation) _then;

/// Create a copy of PendingConversationOperation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? squadId = null,Object? clientNonce = null,Object? createdAt = null,Object? body = null,Object? replyToEntryId = freezed,}) {
  return _then(PendingTextOperation(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,clientNonce: null == clientNonce ? _self.clientNonce : clientNonce // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,replyToEntryId: freezed == replyToEntryId ? _self.replyToEntryId : replyToEntryId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class PendingCardOperation implements PendingConversationOperation {
  const PendingCardOperation({required this.userId, required this.squadId, required this.clientNonce, required this.createdAt, required this.cardId, required this.snapshot, this.encryptedRoute});


@override final  String userId;
@override final  String squadId;
@override final  String clientNonce;
@override final  DateTime createdAt;
 final  String cardId;
 final  CardSnapshot snapshot;
 final  EncryptedRouteBundle? encryptedRoute;

/// Create a copy of PendingConversationOperation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingCardOperationCopyWith<PendingCardOperation> get copyWith => _$PendingCardOperationCopyWithImpl<PendingCardOperation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingCardOperation&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.clientNonce, clientNonce) || other.clientNonce == clientNonce)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cardId, cardId) || other.cardId == cardId)&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot)&&(identical(other.encryptedRoute, encryptedRoute) || other.encryptedRoute == encryptedRoute));
}


@override
int get hashCode => Object.hash(runtimeType,userId,squadId,clientNonce,createdAt,cardId,snapshot,encryptedRoute);

@override
String toString() {
  return 'PendingConversationOperation.card(userId: $userId, squadId: $squadId, clientNonce: $clientNonce, createdAt: $createdAt, cardId: $cardId, snapshot: $snapshot, encryptedRoute: $encryptedRoute)';
}


}

/// @nodoc
abstract mixin class $PendingCardOperationCopyWith<$Res> implements $PendingConversationOperationCopyWith<$Res> {
  factory $PendingCardOperationCopyWith(PendingCardOperation value, $Res Function(PendingCardOperation) _then) = _$PendingCardOperationCopyWithImpl;
@override @useResult
$Res call({
 String userId, String squadId, String clientNonce, DateTime createdAt, String cardId, CardSnapshot snapshot, EncryptedRouteBundle? encryptedRoute
});




}
/// @nodoc
class _$PendingCardOperationCopyWithImpl<$Res>
    implements $PendingCardOperationCopyWith<$Res> {
  _$PendingCardOperationCopyWithImpl(this._self, this._then);

  final PendingCardOperation _self;
  final $Res Function(PendingCardOperation) _then;

/// Create a copy of PendingConversationOperation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? squadId = null,Object? clientNonce = null,Object? createdAt = null,Object? cardId = null,Object? snapshot = null,Object? encryptedRoute = freezed,}) {
  return _then(PendingCardOperation(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,clientNonce: null == clientNonce ? _self.clientNonce : clientNonce // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cardId: null == cardId ? _self.cardId : cardId // ignore: cast_nullable_to_non_nullable
as String,snapshot: null == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as CardSnapshot,encryptedRoute: freezed == encryptedRoute ? _self.encryptedRoute : encryptedRoute // ignore: cast_nullable_to_non_nullable
as EncryptedRouteBundle?,
  ));
}


}

// dart format on
