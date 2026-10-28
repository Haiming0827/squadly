// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'photo_submission.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PhotoSubmissionResult {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoSubmissionResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PhotoSubmissionResult()';
}


}

/// @nodoc
class $PhotoSubmissionResultCopyWith<$Res>  {
$PhotoSubmissionResultCopyWith(PhotoSubmissionResult _, $Res Function(PhotoSubmissionResult) __);
}


/// Adds pattern-matching-related methods to [PhotoSubmissionResult].
extension PhotoSubmissionResultPatterns on PhotoSubmissionResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PhotoSubmissionSent value)?  sent,TResult Function( PhotoSubmissionPending value)?  pending,TResult Function( PhotoSubmissionRejected value)?  rejected,TResult Function( PhotoSubmissionUnconfirmed value)?  unconfirmed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PhotoSubmissionSent() when sent != null:
return sent(_that);case PhotoSubmissionPending() when pending != null:
return pending(_that);case PhotoSubmissionRejected() when rejected != null:
return rejected(_that);case PhotoSubmissionUnconfirmed() when unconfirmed != null:
return unconfirmed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PhotoSubmissionSent value)  sent,required TResult Function( PhotoSubmissionPending value)  pending,required TResult Function( PhotoSubmissionRejected value)  rejected,required TResult Function( PhotoSubmissionUnconfirmed value)  unconfirmed,}){
final _that = this;
switch (_that) {
case PhotoSubmissionSent():
return sent(_that);case PhotoSubmissionPending():
return pending(_that);case PhotoSubmissionRejected():
return rejected(_that);case PhotoSubmissionUnconfirmed():
return unconfirmed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PhotoSubmissionSent value)?  sent,TResult? Function( PhotoSubmissionPending value)?  pending,TResult? Function( PhotoSubmissionRejected value)?  rejected,TResult? Function( PhotoSubmissionUnconfirmed value)?  unconfirmed,}){
final _that = this;
switch (_that) {
case PhotoSubmissionSent() when sent != null:
return sent(_that);case PhotoSubmissionPending() when pending != null:
return pending(_that);case PhotoSubmissionRejected() when rejected != null:
return rejected(_that);case PhotoSubmissionUnconfirmed() when unconfirmed != null:
return unconfirmed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  sent,TResult Function( Failure failure)?  pending,TResult Function( Failure failure)?  rejected,TResult Function( Failure failure)?  unconfirmed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PhotoSubmissionSent() when sent != null:
return sent();case PhotoSubmissionPending() when pending != null:
return pending(_that.failure);case PhotoSubmissionRejected() when rejected != null:
return rejected(_that.failure);case PhotoSubmissionUnconfirmed() when unconfirmed != null:
return unconfirmed(_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  sent,required TResult Function( Failure failure)  pending,required TResult Function( Failure failure)  rejected,required TResult Function( Failure failure)  unconfirmed,}) {final _that = this;
switch (_that) {
case PhotoSubmissionSent():
return sent();case PhotoSubmissionPending():
return pending(_that.failure);case PhotoSubmissionRejected():
return rejected(_that.failure);case PhotoSubmissionUnconfirmed():
return unconfirmed(_that.failure);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  sent,TResult? Function( Failure failure)?  pending,TResult? Function( Failure failure)?  rejected,TResult? Function( Failure failure)?  unconfirmed,}) {final _that = this;
switch (_that) {
case PhotoSubmissionSent() when sent != null:
return sent();case PhotoSubmissionPending() when pending != null:
return pending(_that.failure);case PhotoSubmissionRejected() when rejected != null:
return rejected(_that.failure);case PhotoSubmissionUnconfirmed() when unconfirmed != null:
return unconfirmed(_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class PhotoSubmissionSent implements PhotoSubmissionResult {
  const PhotoSubmissionSent();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoSubmissionSent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PhotoSubmissionResult.sent()';
}


}




/// @nodoc


class PhotoSubmissionPending implements PhotoSubmissionResult {
  const PhotoSubmissionPending(this.failure);
  

 final  Failure failure;

/// Create a copy of PhotoSubmissionResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoSubmissionPendingCopyWith<PhotoSubmissionPending> get copyWith => _$PhotoSubmissionPendingCopyWithImpl<PhotoSubmissionPending>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoSubmissionPending&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,failure);
}

@override
String toString() {
    return 'PhotoSubmissionResult.pending(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $PhotoSubmissionPendingCopyWith<$Res> implements $PhotoSubmissionResultCopyWith<$Res> {
  factory $PhotoSubmissionPendingCopyWith(PhotoSubmissionPending value, $Res Function(PhotoSubmissionPending) _then) = _$PhotoSubmissionPendingCopyWithImpl;
@useResult
$Res call({
 Failure failure
});


$FailureCopyWith<$Res> get failure;

}
/// @nodoc
class _$PhotoSubmissionPendingCopyWithImpl<$Res>
    implements $PhotoSubmissionPendingCopyWith<$Res> {
  _$PhotoSubmissionPendingCopyWithImpl(this._self, this._then);

  final PhotoSubmissionPending _self;
  final $Res Function(PhotoSubmissionPending) _then;

/// Create a copy of PhotoSubmissionResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(PhotoSubmissionPending(
null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,
  ));
}

/// Create a copy of PhotoSubmissionResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FailureCopyWith<$Res> get failure {
  
  return $FailureCopyWith<$Res>(_self.failure, (value) {
    return _then(_self.copyWith(failure: value));
  });
}
}

/// @nodoc


class PhotoSubmissionRejected implements PhotoSubmissionResult {
  const PhotoSubmissionRejected(this.failure);
  

 final  Failure failure;

/// Create a copy of PhotoSubmissionResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoSubmissionRejectedCopyWith<PhotoSubmissionRejected> get copyWith => _$PhotoSubmissionRejectedCopyWithImpl<PhotoSubmissionRejected>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoSubmissionRejected&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,failure);
}

@override
String toString() {
    return 'PhotoSubmissionResult.rejected(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $PhotoSubmissionRejectedCopyWith<$Res> implements $PhotoSubmissionResultCopyWith<$Res> {
  factory $PhotoSubmissionRejectedCopyWith(PhotoSubmissionRejected value, $Res Function(PhotoSubmissionRejected) _then) = _$PhotoSubmissionRejectedCopyWithImpl;
@useResult
$Res call({
 Failure failure
});


$FailureCopyWith<$Res> get failure;

}
/// @nodoc
class _$PhotoSubmissionRejectedCopyWithImpl<$Res>
    implements $PhotoSubmissionRejectedCopyWith<$Res> {
  _$PhotoSubmissionRejectedCopyWithImpl(this._self, this._then);

  final PhotoSubmissionRejected _self;
  final $Res Function(PhotoSubmissionRejected) _then;

/// Create a copy of PhotoSubmissionResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(PhotoSubmissionRejected(
null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,
  ));
}

/// Create a copy of PhotoSubmissionResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FailureCopyWith<$Res> get failure {
  
  return $FailureCopyWith<$Res>(_self.failure, (value) {
    return _then(_self.copyWith(failure: value));
  });
}
}

/// @nodoc


class PhotoSubmissionUnconfirmed implements PhotoSubmissionResult {
  const PhotoSubmissionUnconfirmed(this.failure);
  

 final  Failure failure;

/// Create a copy of PhotoSubmissionResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoSubmissionUnconfirmedCopyWith<PhotoSubmissionUnconfirmed> get copyWith => _$PhotoSubmissionUnconfirmedCopyWithImpl<PhotoSubmissionUnconfirmed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoSubmissionUnconfirmed&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,failure);
}

@override
String toString() {
    return 'PhotoSubmissionResult.unconfirmed(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $PhotoSubmissionUnconfirmedCopyWith<$Res> implements $PhotoSubmissionResultCopyWith<$Res> {
  factory $PhotoSubmissionUnconfirmedCopyWith(PhotoSubmissionUnconfirmed value, $Res Function(PhotoSubmissionUnconfirmed) _then) = _$PhotoSubmissionUnconfirmedCopyWithImpl;
@useResult
$Res call({
 Failure failure
});


$FailureCopyWith<$Res> get failure;

}
/// @nodoc
class _$PhotoSubmissionUnconfirmedCopyWithImpl<$Res>
    implements $PhotoSubmissionUnconfirmedCopyWith<$Res> {
  _$PhotoSubmissionUnconfirmedCopyWithImpl(this._self, this._then);

  final PhotoSubmissionUnconfirmed _self;
  final $Res Function(PhotoSubmissionUnconfirmed) _then;

/// Create a copy of PhotoSubmissionResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(PhotoSubmissionUnconfirmed(
null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,
  ));
}

/// Create a copy of PhotoSubmissionResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FailureCopyWith<$Res> get failure {
  
  return $FailureCopyWith<$Res>(_self.failure, (value) {
    return _then(_self.copyWith(failure: value));
  });
}
}

// dart format on
