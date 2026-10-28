// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'photo_head.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PhotoHead {

 String get revision; TimelineEntry? get photo;
/// Create a copy of PhotoHead
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoHeadCopyWith<PhotoHead> get copyWith => _$PhotoHeadCopyWithImpl<PhotoHead>(this as PhotoHead, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PhotoHead;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoHead&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.photo, _this.photo) || other.photo == _this.photo));
}


@override
int get hashCode {
  final _this = this as PhotoHead;
  return Object.hash(runtimeType,_this.revision,_this.photo);
}

@override
String toString() {
  final _this = this as PhotoHead;
  return 'PhotoHead(revision: ${_this.revision}, photo: ${_this.photo})';
}


}

/// @nodoc
abstract mixin class $PhotoHeadCopyWith<$Res>  {
  factory $PhotoHeadCopyWith(PhotoHead value, $Res Function(PhotoHead) _then) = _$PhotoHeadCopyWithImpl;
@useResult
$Res call({
 String revision, TimelineEntry? photo
});




}
/// @nodoc
class _$PhotoHeadCopyWithImpl<$Res>
    implements $PhotoHeadCopyWith<$Res> {
  _$PhotoHeadCopyWithImpl(this._self, this._then);

  final PhotoHead _self;
  final $Res Function(PhotoHead) _then;

/// Create a copy of PhotoHead
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? revision = null,Object? photo = freezed,}) {
  return _then(PhotoHead(
revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as String,photo: freezed == photo ? _self.photo : photo // ignore: cast_nullable_to_non_nullable
as TimelineEntry?,
  ));
}

}


/// Adds pattern-matching-related methods to [PhotoHead].
extension PhotoHeadPatterns on PhotoHead {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoHead value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoHead() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoHead value)  $default,){
final _that = this;
switch (_that) {
case _PhotoHead():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoHead value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoHead() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String revision,  TimelineEntry? photo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoHead() when $default != null:
return $default(_that.revision,_that.photo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String revision,  TimelineEntry? photo)  $default,) {final _that = this;
switch (_that) {
case _PhotoHead():
return $default(_that.revision,_that.photo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String revision,  TimelineEntry? photo)?  $default,) {final _that = this;
switch (_that) {
case _PhotoHead() when $default != null:
return $default(_that.revision,_that.photo);case _:
  return null;

}
}

}

/// @nodoc


class _PhotoHead implements PhotoHead {
  const _PhotoHead({required this.revision, this.photo});


@override final  String revision;
@override final  TimelineEntry? photo;

/// Create a copy of PhotoHead
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoHeadCopyWith<_PhotoHead> get copyWith => __$PhotoHeadCopyWithImpl<_PhotoHead>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoHead&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.photo, photo) || other.photo == photo));
}


@override
int get hashCode {
    return Object.hash(runtimeType,revision,photo);
}

@override
String toString() {
    return 'PhotoHead(revision: $revision, photo: $photo)';
}


}

/// @nodoc
abstract mixin class _$PhotoHeadCopyWith<$Res> implements $PhotoHeadCopyWith<$Res> {
  factory _$PhotoHeadCopyWith(_PhotoHead value, $Res Function(_PhotoHead) _then) = __$PhotoHeadCopyWithImpl;
@override @useResult
$Res call({
 String revision, TimelineEntry? photo
});




}
/// @nodoc
class __$PhotoHeadCopyWithImpl<$Res>
    implements _$PhotoHeadCopyWith<$Res> {
  __$PhotoHeadCopyWithImpl(this._self, this._then);

  final _PhotoHead _self;
  final $Res Function(_PhotoHead) _then;

/// Create a copy of PhotoHead
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? revision = null,Object? photo = freezed,}) {
  return _then(_PhotoHead(
revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as String,photo: freezed == photo ? _self.photo : photo // ignore: cast_nullable_to_non_nullable
as TimelineEntry?,
  ));
}


}

// dart format on
