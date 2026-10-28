// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'photo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PhotoAttachment {

 String get mediaId; int get width; int get height; int get byteLength; bool get isRevoked;
/// Create a copy of PhotoAttachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoAttachmentCopyWith<PhotoAttachment> get copyWith => _$PhotoAttachmentCopyWithImpl<PhotoAttachment>(this as PhotoAttachment, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PhotoAttachment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoAttachment&&(identical(other.mediaId, _this.mediaId) || other.mediaId == _this.mediaId)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.byteLength, _this.byteLength) || other.byteLength == _this.byteLength)&&(identical(other.isRevoked, _this.isRevoked) || other.isRevoked == _this.isRevoked));
}


@override
int get hashCode {
  final _this = this as PhotoAttachment;
  return Object.hash(runtimeType,_this.mediaId,_this.width,_this.height,_this.byteLength,_this.isRevoked);
}

@override
String toString() {
  final _this = this as PhotoAttachment;
  return 'PhotoAttachment(mediaId: ${_this.mediaId}, width: ${_this.width}, height: ${_this.height}, byteLength: ${_this.byteLength}, isRevoked: ${_this.isRevoked})';
}


}

/// @nodoc
abstract mixin class $PhotoAttachmentCopyWith<$Res>  {
  factory $PhotoAttachmentCopyWith(PhotoAttachment value, $Res Function(PhotoAttachment) _then) = _$PhotoAttachmentCopyWithImpl;
@useResult
$Res call({
 String mediaId, int width, int height, int byteLength, bool isRevoked
});




}
/// @nodoc
class _$PhotoAttachmentCopyWithImpl<$Res>
    implements $PhotoAttachmentCopyWith<$Res> {
  _$PhotoAttachmentCopyWithImpl(this._self, this._then);

  final PhotoAttachment _self;
  final $Res Function(PhotoAttachment) _then;

/// Create a copy of PhotoAttachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mediaId = null,Object? width = null,Object? height = null,Object? byteLength = null,Object? isRevoked = null,}) {
  return _then(PhotoAttachment(
mediaId: null == mediaId ? _self.mediaId : mediaId // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,byteLength: null == byteLength ? _self.byteLength : byteLength // ignore: cast_nullable_to_non_nullable
as int,isRevoked: null == isRevoked ? _self.isRevoked : isRevoked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PhotoAttachment].
extension PhotoAttachmentPatterns on PhotoAttachment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoAttachment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoAttachment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoAttachment value)  $default,){
final _that = this;
switch (_that) {
case _PhotoAttachment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoAttachment value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoAttachment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String mediaId,  int width,  int height,  int byteLength,  bool isRevoked)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoAttachment() when $default != null:
return $default(_that.mediaId,_that.width,_that.height,_that.byteLength,_that.isRevoked);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String mediaId,  int width,  int height,  int byteLength,  bool isRevoked)  $default,) {final _that = this;
switch (_that) {
case _PhotoAttachment():
return $default(_that.mediaId,_that.width,_that.height,_that.byteLength,_that.isRevoked);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String mediaId,  int width,  int height,  int byteLength,  bool isRevoked)?  $default,) {final _that = this;
switch (_that) {
case _PhotoAttachment() when $default != null:
return $default(_that.mediaId,_that.width,_that.height,_that.byteLength,_that.isRevoked);case _:
  return null;

}
}

}

/// @nodoc


class _PhotoAttachment implements PhotoAttachment {
  const _PhotoAttachment({required this.mediaId, required this.width, required this.height, required this.byteLength, required this.isRevoked});
  

@override final  String mediaId;
@override final  int width;
@override final  int height;
@override final  int byteLength;
@override final  bool isRevoked;

/// Create a copy of PhotoAttachment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoAttachmentCopyWith<_PhotoAttachment> get copyWith => __$PhotoAttachmentCopyWithImpl<_PhotoAttachment>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoAttachment&&(identical(other.mediaId, mediaId) || other.mediaId == mediaId)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.byteLength, byteLength) || other.byteLength == byteLength)&&(identical(other.isRevoked, isRevoked) || other.isRevoked == isRevoked));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mediaId,width,height,byteLength,isRevoked);
}

@override
String toString() {
    return 'PhotoAttachment(mediaId: $mediaId, width: $width, height: $height, byteLength: $byteLength, isRevoked: $isRevoked)';
}


}

/// @nodoc
abstract mixin class _$PhotoAttachmentCopyWith<$Res> implements $PhotoAttachmentCopyWith<$Res> {
  factory _$PhotoAttachmentCopyWith(_PhotoAttachment value, $Res Function(_PhotoAttachment) _then) = __$PhotoAttachmentCopyWithImpl;
@override @useResult
$Res call({
 String mediaId, int width, int height, int byteLength, bool isRevoked
});




}
/// @nodoc
class __$PhotoAttachmentCopyWithImpl<$Res>
    implements _$PhotoAttachmentCopyWith<$Res> {
  __$PhotoAttachmentCopyWithImpl(this._self, this._then);

  final _PhotoAttachment _self;
  final $Res Function(_PhotoAttachment) _then;

/// Create a copy of PhotoAttachment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mediaId = null,Object? width = null,Object? height = null,Object? byteLength = null,Object? isRevoked = null,}) {
  return _then(_PhotoAttachment(
mediaId: null == mediaId ? _self.mediaId : mediaId // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,byteLength: null == byteLength ? _self.byteLength : byteLength // ignore: cast_nullable_to_non_nullable
as int,isRevoked: null == isRevoked ? _self.isRevoked : isRevoked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$PhotoTarget {

 String get userId; String get squadId; String get squadName; String? get replyToMessageId;
/// Create a copy of PhotoTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoTargetCopyWith<PhotoTarget> get copyWith => _$PhotoTargetCopyWithImpl<PhotoTarget>(this as PhotoTarget, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PhotoTarget;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoTarget&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.squadId, _this.squadId) || other.squadId == _this.squadId)&&(identical(other.squadName, _this.squadName) || other.squadName == _this.squadName)&&(identical(other.replyToMessageId, _this.replyToMessageId) || other.replyToMessageId == _this.replyToMessageId));
}


@override
int get hashCode {
  final _this = this as PhotoTarget;
  return Object.hash(runtimeType,_this.userId,_this.squadId,_this.squadName,_this.replyToMessageId);
}

@override
String toString() {
  final _this = this as PhotoTarget;
  return 'PhotoTarget(userId: ${_this.userId}, squadId: ${_this.squadId}, squadName: ${_this.squadName}, replyToMessageId: ${_this.replyToMessageId})';
}


}

/// @nodoc
abstract mixin class $PhotoTargetCopyWith<$Res>  {
  factory $PhotoTargetCopyWith(PhotoTarget value, $Res Function(PhotoTarget) _then) = _$PhotoTargetCopyWithImpl;
@useResult
$Res call({
 String userId, String squadId, String squadName, String? replyToMessageId
});




}
/// @nodoc
class _$PhotoTargetCopyWithImpl<$Res>
    implements $PhotoTargetCopyWith<$Res> {
  _$PhotoTargetCopyWithImpl(this._self, this._then);

  final PhotoTarget _self;
  final $Res Function(PhotoTarget) _then;

/// Create a copy of PhotoTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? squadId = null,Object? squadName = null,Object? replyToMessageId = freezed,}) {
  return _then(PhotoTarget(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,squadName: null == squadName ? _self.squadName : squadName // ignore: cast_nullable_to_non_nullable
as String,replyToMessageId: freezed == replyToMessageId ? _self.replyToMessageId : replyToMessageId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PhotoTarget].
extension PhotoTargetPatterns on PhotoTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoTarget value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoTarget() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoTarget value)  $default,){
final _that = this;
switch (_that) {
case _PhotoTarget():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoTarget value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoTarget() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String squadId,  String squadName,  String? replyToMessageId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoTarget() when $default != null:
return $default(_that.userId,_that.squadId,_that.squadName,_that.replyToMessageId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String squadId,  String squadName,  String? replyToMessageId)  $default,) {final _that = this;
switch (_that) {
case _PhotoTarget():
return $default(_that.userId,_that.squadId,_that.squadName,_that.replyToMessageId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String squadId,  String squadName,  String? replyToMessageId)?  $default,) {final _that = this;
switch (_that) {
case _PhotoTarget() when $default != null:
return $default(_that.userId,_that.squadId,_that.squadName,_that.replyToMessageId);case _:
  return null;

}
}

}

/// @nodoc


class _PhotoTarget implements PhotoTarget {
  const _PhotoTarget({required this.userId, required this.squadId, required this.squadName, this.replyToMessageId});
  

@override final  String userId;
@override final  String squadId;
@override final  String squadName;
@override final  String? replyToMessageId;

/// Create a copy of PhotoTarget
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoTargetCopyWith<_PhotoTarget> get copyWith => __$PhotoTargetCopyWithImpl<_PhotoTarget>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoTarget&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.squadName, squadName) || other.squadName == squadName)&&(identical(other.replyToMessageId, replyToMessageId) || other.replyToMessageId == replyToMessageId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,userId,squadId,squadName,replyToMessageId);
}

@override
String toString() {
    return 'PhotoTarget(userId: $userId, squadId: $squadId, squadName: $squadName, replyToMessageId: $replyToMessageId)';
}


}

/// @nodoc
abstract mixin class _$PhotoTargetCopyWith<$Res> implements $PhotoTargetCopyWith<$Res> {
  factory _$PhotoTargetCopyWith(_PhotoTarget value, $Res Function(_PhotoTarget) _then) = __$PhotoTargetCopyWithImpl;
@override @useResult
$Res call({
 String userId, String squadId, String squadName, String? replyToMessageId
});




}
/// @nodoc
class __$PhotoTargetCopyWithImpl<$Res>
    implements _$PhotoTargetCopyWith<$Res> {
  __$PhotoTargetCopyWithImpl(this._self, this._then);

  final _PhotoTarget _self;
  final $Res Function(_PhotoTarget) _then;

/// Create a copy of PhotoTarget
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? squadId = null,Object? squadName = null,Object? replyToMessageId = freezed,}) {
  return _then(_PhotoTarget(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,squadName: null == squadName ? _self.squadName : squadName // ignore: cast_nullable_to_non_nullable
as String,replyToMessageId: freezed == replyToMessageId ? _self.replyToMessageId : replyToMessageId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$PhotoDraft {

 PhotoTarget get target; PhotoImage get image; String get clientNonce; DateTime get preparedAt;
/// Create a copy of PhotoDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoDraftCopyWith<PhotoDraft> get copyWith => _$PhotoDraftCopyWithImpl<PhotoDraft>(this as PhotoDraft, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PhotoDraft;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoDraft&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.image, _this.image) || other.image == _this.image)&&(identical(other.clientNonce, _this.clientNonce) || other.clientNonce == _this.clientNonce)&&(identical(other.preparedAt, _this.preparedAt) || other.preparedAt == _this.preparedAt));
}


@override
int get hashCode {
  final _this = this as PhotoDraft;
  return Object.hash(runtimeType,_this.target,_this.image,_this.clientNonce,_this.preparedAt);
}

@override
String toString() {
  final _this = this as PhotoDraft;
  return 'PhotoDraft(target: ${_this.target}, image: ${_this.image}, clientNonce: ${_this.clientNonce}, preparedAt: ${_this.preparedAt})';
}


}

/// @nodoc
abstract mixin class $PhotoDraftCopyWith<$Res>  {
  factory $PhotoDraftCopyWith(PhotoDraft value, $Res Function(PhotoDraft) _then) = _$PhotoDraftCopyWithImpl;
@useResult
$Res call({
 PhotoTarget target, PhotoImage image, String clientNonce, DateTime preparedAt
});


$PhotoTargetCopyWith<$Res> get target;

}
/// @nodoc
class _$PhotoDraftCopyWithImpl<$Res>
    implements $PhotoDraftCopyWith<$Res> {
  _$PhotoDraftCopyWithImpl(this._self, this._then);

  final PhotoDraft _self;
  final $Res Function(PhotoDraft) _then;

/// Create a copy of PhotoDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? image = null,Object? clientNonce = null,Object? preparedAt = null,}) {
  return _then(PhotoDraft(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as PhotoTarget,image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as PhotoImage,clientNonce: null == clientNonce ? _self.clientNonce : clientNonce // ignore: cast_nullable_to_non_nullable
as String,preparedAt: null == preparedAt ? _self.preparedAt : preparedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of PhotoDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PhotoTargetCopyWith<$Res> get target {
  
  return $PhotoTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}


/// Adds pattern-matching-related methods to [PhotoDraft].
extension PhotoDraftPatterns on PhotoDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoDraft value)  $default,){
final _that = this;
switch (_that) {
case _PhotoDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoDraft value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PhotoTarget target,  PhotoImage image,  String clientNonce,  DateTime preparedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoDraft() when $default != null:
return $default(_that.target,_that.image,_that.clientNonce,_that.preparedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PhotoTarget target,  PhotoImage image,  String clientNonce,  DateTime preparedAt)  $default,) {final _that = this;
switch (_that) {
case _PhotoDraft():
return $default(_that.target,_that.image,_that.clientNonce,_that.preparedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PhotoTarget target,  PhotoImage image,  String clientNonce,  DateTime preparedAt)?  $default,) {final _that = this;
switch (_that) {
case _PhotoDraft() when $default != null:
return $default(_that.target,_that.image,_that.clientNonce,_that.preparedAt);case _:
  return null;

}
}

}

/// @nodoc


class _PhotoDraft implements PhotoDraft {
  const _PhotoDraft({required this.target, required this.image, required this.clientNonce, required this.preparedAt});
  

@override final  PhotoTarget target;
@override final  PhotoImage image;
@override final  String clientNonce;
@override final  DateTime preparedAt;

/// Create a copy of PhotoDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoDraftCopyWith<_PhotoDraft> get copyWith => __$PhotoDraftCopyWithImpl<_PhotoDraft>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoDraft&&(identical(other.target, target) || other.target == target)&&(identical(other.image, image) || other.image == image)&&(identical(other.clientNonce, clientNonce) || other.clientNonce == clientNonce)&&(identical(other.preparedAt, preparedAt) || other.preparedAt == preparedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,target,image,clientNonce,preparedAt);
}

@override
String toString() {
    return 'PhotoDraft(target: $target, image: $image, clientNonce: $clientNonce, preparedAt: $preparedAt)';
}


}

/// @nodoc
abstract mixin class _$PhotoDraftCopyWith<$Res> implements $PhotoDraftCopyWith<$Res> {
  factory _$PhotoDraftCopyWith(_PhotoDraft value, $Res Function(_PhotoDraft) _then) = __$PhotoDraftCopyWithImpl;
@override @useResult
$Res call({
 PhotoTarget target, PhotoImage image, String clientNonce, DateTime preparedAt
});


@override $PhotoTargetCopyWith<$Res> get target;

}
/// @nodoc
class __$PhotoDraftCopyWithImpl<$Res>
    implements _$PhotoDraftCopyWith<$Res> {
  __$PhotoDraftCopyWithImpl(this._self, this._then);

  final _PhotoDraft _self;
  final $Res Function(_PhotoDraft) _then;

/// Create a copy of PhotoDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? image = null,Object? clientNonce = null,Object? preparedAt = null,}) {
  return _then(_PhotoDraft(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as PhotoTarget,image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as PhotoImage,clientNonce: null == clientNonce ? _self.clientNonce : clientNonce // ignore: cast_nullable_to_non_nullable
as String,preparedAt: null == preparedAt ? _self.preparedAt : preparedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of PhotoDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PhotoTargetCopyWith<$Res> get target {
  
  return $PhotoTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}

/// @nodoc
mixin _$PublishedPhoto {

 String get messageId; String get mediaId; String get squadId; String get authorId; String get clientNonce; DateTime get publishedAt; String? get replyToMessageId;
/// Create a copy of PublishedPhoto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublishedPhotoCopyWith<PublishedPhoto> get copyWith => _$PublishedPhotoCopyWithImpl<PublishedPhoto>(this as PublishedPhoto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PublishedPhoto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublishedPhoto&&(identical(other.messageId, _this.messageId) || other.messageId == _this.messageId)&&(identical(other.mediaId, _this.mediaId) || other.mediaId == _this.mediaId)&&(identical(other.squadId, _this.squadId) || other.squadId == _this.squadId)&&(identical(other.authorId, _this.authorId) || other.authorId == _this.authorId)&&(identical(other.clientNonce, _this.clientNonce) || other.clientNonce == _this.clientNonce)&&(identical(other.publishedAt, _this.publishedAt) || other.publishedAt == _this.publishedAt)&&(identical(other.replyToMessageId, _this.replyToMessageId) || other.replyToMessageId == _this.replyToMessageId));
}


@override
int get hashCode {
  final _this = this as PublishedPhoto;
  return Object.hash(runtimeType,_this.messageId,_this.mediaId,_this.squadId,_this.authorId,_this.clientNonce,_this.publishedAt,_this.replyToMessageId);
}

@override
String toString() {
  final _this = this as PublishedPhoto;
  return 'PublishedPhoto(messageId: ${_this.messageId}, mediaId: ${_this.mediaId}, squadId: ${_this.squadId}, authorId: ${_this.authorId}, clientNonce: ${_this.clientNonce}, publishedAt: ${_this.publishedAt}, replyToMessageId: ${_this.replyToMessageId})';
}


}

/// @nodoc
abstract mixin class $PublishedPhotoCopyWith<$Res>  {
  factory $PublishedPhotoCopyWith(PublishedPhoto value, $Res Function(PublishedPhoto) _then) = _$PublishedPhotoCopyWithImpl;
@useResult
$Res call({
 String messageId, String mediaId, String squadId, String authorId, String clientNonce, DateTime publishedAt, String? replyToMessageId
});




}
/// @nodoc
class _$PublishedPhotoCopyWithImpl<$Res>
    implements $PublishedPhotoCopyWith<$Res> {
  _$PublishedPhotoCopyWithImpl(this._self, this._then);

  final PublishedPhoto _self;
  final $Res Function(PublishedPhoto) _then;

/// Create a copy of PublishedPhoto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? mediaId = null,Object? squadId = null,Object? authorId = null,Object? clientNonce = null,Object? publishedAt = null,Object? replyToMessageId = freezed,}) {
  return _then(PublishedPhoto(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,mediaId: null == mediaId ? _self.mediaId : mediaId // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,clientNonce: null == clientNonce ? _self.clientNonce : clientNonce // ignore: cast_nullable_to_non_nullable
as String,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,replyToMessageId: freezed == replyToMessageId ? _self.replyToMessageId : replyToMessageId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PublishedPhoto].
extension PublishedPhotoPatterns on PublishedPhoto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublishedPhoto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublishedPhoto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublishedPhoto value)  $default,){
final _that = this;
switch (_that) {
case _PublishedPhoto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublishedPhoto value)?  $default,){
final _that = this;
switch (_that) {
case _PublishedPhoto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId,  String mediaId,  String squadId,  String authorId,  String clientNonce,  DateTime publishedAt,  String? replyToMessageId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublishedPhoto() when $default != null:
return $default(_that.messageId,_that.mediaId,_that.squadId,_that.authorId,_that.clientNonce,_that.publishedAt,_that.replyToMessageId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId,  String mediaId,  String squadId,  String authorId,  String clientNonce,  DateTime publishedAt,  String? replyToMessageId)  $default,) {final _that = this;
switch (_that) {
case _PublishedPhoto():
return $default(_that.messageId,_that.mediaId,_that.squadId,_that.authorId,_that.clientNonce,_that.publishedAt,_that.replyToMessageId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId,  String mediaId,  String squadId,  String authorId,  String clientNonce,  DateTime publishedAt,  String? replyToMessageId)?  $default,) {final _that = this;
switch (_that) {
case _PublishedPhoto() when $default != null:
return $default(_that.messageId,_that.mediaId,_that.squadId,_that.authorId,_that.clientNonce,_that.publishedAt,_that.replyToMessageId);case _:
  return null;

}
}

}

/// @nodoc


class _PublishedPhoto implements PublishedPhoto {
  const _PublishedPhoto({required this.messageId, required this.mediaId, required this.squadId, required this.authorId, required this.clientNonce, required this.publishedAt, this.replyToMessageId});
  

@override final  String messageId;
@override final  String mediaId;
@override final  String squadId;
@override final  String authorId;
@override final  String clientNonce;
@override final  DateTime publishedAt;
@override final  String? replyToMessageId;

/// Create a copy of PublishedPhoto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublishedPhotoCopyWith<_PublishedPhoto> get copyWith => __$PublishedPhotoCopyWithImpl<_PublishedPhoto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublishedPhoto&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.mediaId, mediaId) || other.mediaId == mediaId)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.clientNonce, clientNonce) || other.clientNonce == clientNonce)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.replyToMessageId, replyToMessageId) || other.replyToMessageId == replyToMessageId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,messageId,mediaId,squadId,authorId,clientNonce,publishedAt,replyToMessageId);
}

@override
String toString() {
    return 'PublishedPhoto(messageId: $messageId, mediaId: $mediaId, squadId: $squadId, authorId: $authorId, clientNonce: $clientNonce, publishedAt: $publishedAt, replyToMessageId: $replyToMessageId)';
}


}

/// @nodoc
abstract mixin class _$PublishedPhotoCopyWith<$Res> implements $PublishedPhotoCopyWith<$Res> {
  factory _$PublishedPhotoCopyWith(_PublishedPhoto value, $Res Function(_PublishedPhoto) _then) = __$PublishedPhotoCopyWithImpl;
@override @useResult
$Res call({
 String messageId, String mediaId, String squadId, String authorId, String clientNonce, DateTime publishedAt, String? replyToMessageId
});




}
/// @nodoc
class __$PublishedPhotoCopyWithImpl<$Res>
    implements _$PublishedPhotoCopyWith<$Res> {
  __$PublishedPhotoCopyWithImpl(this._self, this._then);

  final _PublishedPhoto _self;
  final $Res Function(_PublishedPhoto) _then;

/// Create a copy of PublishedPhoto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? mediaId = null,Object? squadId = null,Object? authorId = null,Object? clientNonce = null,Object? publishedAt = null,Object? replyToMessageId = freezed,}) {
  return _then(_PublishedPhoto(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,mediaId: null == mediaId ? _self.mediaId : mediaId // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,clientNonce: null == clientNonce ? _self.clientNonce : clientNonce // ignore: cast_nullable_to_non_nullable
as String,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,replyToMessageId: freezed == replyToMessageId ? _self.replyToMessageId : replyToMessageId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
