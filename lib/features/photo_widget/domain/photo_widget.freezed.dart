// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'photo_widget.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PhotoWidgetContext {

 String get environmentId; String get userId; DateTime get expiresAt; int get revision;
/// Create a copy of PhotoWidgetContext
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoWidgetContextCopyWith<PhotoWidgetContext> get copyWith => _$PhotoWidgetContextCopyWithImpl<PhotoWidgetContext>(this as PhotoWidgetContext, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PhotoWidgetContext;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoWidgetContext&&(identical(other.environmentId, _this.environmentId) || other.environmentId == _this.environmentId)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.revision, _this.revision) || other.revision == _this.revision));
}


@override
int get hashCode {
  final _this = this as PhotoWidgetContext;
  return Object.hash(runtimeType,_this.environmentId,_this.userId,_this.expiresAt,_this.revision);
}

@override
String toString() {
  final _this = this as PhotoWidgetContext;
  return 'PhotoWidgetContext(environmentId: ${_this.environmentId}, userId: ${_this.userId}, expiresAt: ${_this.expiresAt}, revision: ${_this.revision})';
}


}

/// @nodoc
abstract mixin class $PhotoWidgetContextCopyWith<$Res>  {
  factory $PhotoWidgetContextCopyWith(PhotoWidgetContext value, $Res Function(PhotoWidgetContext) _then) = _$PhotoWidgetContextCopyWithImpl;
@useResult
$Res call({
 String environmentId, String userId, DateTime expiresAt, int revision
});




}
/// @nodoc
class _$PhotoWidgetContextCopyWithImpl<$Res>
    implements $PhotoWidgetContextCopyWith<$Res> {
  _$PhotoWidgetContextCopyWithImpl(this._self, this._then);

  final PhotoWidgetContext _self;
  final $Res Function(PhotoWidgetContext) _then;

/// Create a copy of PhotoWidgetContext
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? environmentId = null,Object? userId = null,Object? expiresAt = null,Object? revision = null,}) {
  return _then(PhotoWidgetContext(
environmentId: null == environmentId ? _self.environmentId : environmentId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PhotoWidgetContext].
extension PhotoWidgetContextPatterns on PhotoWidgetContext {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoWidgetContext value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoWidgetContext() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoWidgetContext value)  $default,){
final _that = this;
switch (_that) {
case _PhotoWidgetContext():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoWidgetContext value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoWidgetContext() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String environmentId,  String userId,  DateTime expiresAt,  int revision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoWidgetContext() when $default != null:
return $default(_that.environmentId,_that.userId,_that.expiresAt,_that.revision);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String environmentId,  String userId,  DateTime expiresAt,  int revision)  $default,) {final _that = this;
switch (_that) {
case _PhotoWidgetContext():
return $default(_that.environmentId,_that.userId,_that.expiresAt,_that.revision);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String environmentId,  String userId,  DateTime expiresAt,  int revision)?  $default,) {final _that = this;
switch (_that) {
case _PhotoWidgetContext() when $default != null:
return $default(_that.environmentId,_that.userId,_that.expiresAt,_that.revision);case _:
  return null;

}
}

}

/// @nodoc


class _PhotoWidgetContext implements PhotoWidgetContext {
  const _PhotoWidgetContext({required this.environmentId, required this.userId, required this.expiresAt, this.revision = 0});
  

@override final  String environmentId;
@override final  String userId;
@override final  DateTime expiresAt;
@override@JsonKey() final  int revision;

/// Create a copy of PhotoWidgetContext
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoWidgetContextCopyWith<_PhotoWidgetContext> get copyWith => __$PhotoWidgetContextCopyWithImpl<_PhotoWidgetContext>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoWidgetContext&&(identical(other.environmentId, environmentId) || other.environmentId == environmentId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.revision, revision) || other.revision == revision));
}


@override
int get hashCode {
    return Object.hash(runtimeType,environmentId,userId,expiresAt,revision);
}

@override
String toString() {
    return 'PhotoWidgetContext(environmentId: $environmentId, userId: $userId, expiresAt: $expiresAt, revision: $revision)';
}


}

/// @nodoc
abstract mixin class _$PhotoWidgetContextCopyWith<$Res> implements $PhotoWidgetContextCopyWith<$Res> {
  factory _$PhotoWidgetContextCopyWith(_PhotoWidgetContext value, $Res Function(_PhotoWidgetContext) _then) = __$PhotoWidgetContextCopyWithImpl;
@override @useResult
$Res call({
 String environmentId, String userId, DateTime expiresAt, int revision
});




}
/// @nodoc
class __$PhotoWidgetContextCopyWithImpl<$Res>
    implements _$PhotoWidgetContextCopyWith<$Res> {
  __$PhotoWidgetContextCopyWithImpl(this._self, this._then);

  final _PhotoWidgetContext _self;
  final $Res Function(_PhotoWidgetContext) _then;

/// Create a copy of PhotoWidgetContext
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? environmentId = null,Object? userId = null,Object? expiresAt = null,Object? revision = null,}) {
  return _then(_PhotoWidgetContext(
environmentId: null == environmentId ? _self.environmentId : environmentId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$PhotoWidgetLease {

 String get scope; String get generation; DateTime get expiresAt;
/// Create a copy of PhotoWidgetLease
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoWidgetLeaseCopyWith<PhotoWidgetLease> get copyWith => _$PhotoWidgetLeaseCopyWithImpl<PhotoWidgetLease>(this as PhotoWidgetLease, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PhotoWidgetLease;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoWidgetLease&&(identical(other.scope, _this.scope) || other.scope == _this.scope)&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt));
}


@override
int get hashCode {
  final _this = this as PhotoWidgetLease;
  return Object.hash(runtimeType,_this.scope,_this.generation,_this.expiresAt);
}

@override
String toString() {
  final _this = this as PhotoWidgetLease;
  return 'PhotoWidgetLease(scope: ${_this.scope}, generation: ${_this.generation}, expiresAt: ${_this.expiresAt})';
}


}

/// @nodoc
abstract mixin class $PhotoWidgetLeaseCopyWith<$Res>  {
  factory $PhotoWidgetLeaseCopyWith(PhotoWidgetLease value, $Res Function(PhotoWidgetLease) _then) = _$PhotoWidgetLeaseCopyWithImpl;
@useResult
$Res call({
 String scope, String generation, DateTime expiresAt
});




}
/// @nodoc
class _$PhotoWidgetLeaseCopyWithImpl<$Res>
    implements $PhotoWidgetLeaseCopyWith<$Res> {
  _$PhotoWidgetLeaseCopyWithImpl(this._self, this._then);

  final PhotoWidgetLease _self;
  final $Res Function(PhotoWidgetLease) _then;

/// Create a copy of PhotoWidgetLease
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? scope = null,Object? generation = null,Object? expiresAt = null,}) {
  return _then(PhotoWidgetLease(
scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [PhotoWidgetLease].
extension PhotoWidgetLeasePatterns on PhotoWidgetLease {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoWidgetLease value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoWidgetLease() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoWidgetLease value)  $default,){
final _that = this;
switch (_that) {
case _PhotoWidgetLease():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoWidgetLease value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoWidgetLease() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String scope,  String generation,  DateTime expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoWidgetLease() when $default != null:
return $default(_that.scope,_that.generation,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String scope,  String generation,  DateTime expiresAt)  $default,) {final _that = this;
switch (_that) {
case _PhotoWidgetLease():
return $default(_that.scope,_that.generation,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String scope,  String generation,  DateTime expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _PhotoWidgetLease() when $default != null:
return $default(_that.scope,_that.generation,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc


class _PhotoWidgetLease implements PhotoWidgetLease {
  const _PhotoWidgetLease({required this.scope, required this.generation, required this.expiresAt});
  

@override final  String scope;
@override final  String generation;
@override final  DateTime expiresAt;

/// Create a copy of PhotoWidgetLease
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoWidgetLeaseCopyWith<_PhotoWidgetLease> get copyWith => __$PhotoWidgetLeaseCopyWithImpl<_PhotoWidgetLease>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoWidgetLease&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,scope,generation,expiresAt);
}

@override
String toString() {
    return 'PhotoWidgetLease(scope: $scope, generation: $generation, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$PhotoWidgetLeaseCopyWith<$Res> implements $PhotoWidgetLeaseCopyWith<$Res> {
  factory _$PhotoWidgetLeaseCopyWith(_PhotoWidgetLease value, $Res Function(_PhotoWidgetLease) _then) = __$PhotoWidgetLeaseCopyWithImpl;
@override @useResult
$Res call({
 String scope, String generation, DateTime expiresAt
});




}
/// @nodoc
class __$PhotoWidgetLeaseCopyWithImpl<$Res>
    implements _$PhotoWidgetLeaseCopyWith<$Res> {
  __$PhotoWidgetLeaseCopyWithImpl(this._self, this._then);

  final _PhotoWidgetLease _self;
  final $Res Function(_PhotoWidgetLease) _then;

/// Create a copy of PhotoWidgetLease
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? scope = null,Object? generation = null,Object? expiresAt = null,}) {
  return _then(_PhotoWidgetLease(
scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$PhotoWidgetBinding {

 String get id; String get scope; String get squadId; String get squadName; bool get previewEnabled;
/// Create a copy of PhotoWidgetBinding
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoWidgetBindingCopyWith<PhotoWidgetBinding> get copyWith => _$PhotoWidgetBindingCopyWithImpl<PhotoWidgetBinding>(this as PhotoWidgetBinding, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PhotoWidgetBinding;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoWidgetBinding&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.scope, _this.scope) || other.scope == _this.scope)&&(identical(other.squadId, _this.squadId) || other.squadId == _this.squadId)&&(identical(other.squadName, _this.squadName) || other.squadName == _this.squadName)&&(identical(other.previewEnabled, _this.previewEnabled) || other.previewEnabled == _this.previewEnabled));
}


@override
int get hashCode {
  final _this = this as PhotoWidgetBinding;
  return Object.hash(runtimeType,_this.id,_this.scope,_this.squadId,_this.squadName,_this.previewEnabled);
}

@override
String toString() {
  final _this = this as PhotoWidgetBinding;
  return 'PhotoWidgetBinding(id: ${_this.id}, scope: ${_this.scope}, squadId: ${_this.squadId}, squadName: ${_this.squadName}, previewEnabled: ${_this.previewEnabled})';
}


}

/// @nodoc
abstract mixin class $PhotoWidgetBindingCopyWith<$Res>  {
  factory $PhotoWidgetBindingCopyWith(PhotoWidgetBinding value, $Res Function(PhotoWidgetBinding) _then) = _$PhotoWidgetBindingCopyWithImpl;
@useResult
$Res call({
 String id, String scope, String squadId, String squadName, bool previewEnabled
});




}
/// @nodoc
class _$PhotoWidgetBindingCopyWithImpl<$Res>
    implements $PhotoWidgetBindingCopyWith<$Res> {
  _$PhotoWidgetBindingCopyWithImpl(this._self, this._then);

  final PhotoWidgetBinding _self;
  final $Res Function(PhotoWidgetBinding) _then;

/// Create a copy of PhotoWidgetBinding
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? scope = null,Object? squadId = null,Object? squadName = null,Object? previewEnabled = null,}) {
  return _then(PhotoWidgetBinding(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,squadName: null == squadName ? _self.squadName : squadName // ignore: cast_nullable_to_non_nullable
as String,previewEnabled: null == previewEnabled ? _self.previewEnabled : previewEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PhotoWidgetBinding].
extension PhotoWidgetBindingPatterns on PhotoWidgetBinding {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoWidgetBinding value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoWidgetBinding() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoWidgetBinding value)  $default,){
final _that = this;
switch (_that) {
case _PhotoWidgetBinding():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoWidgetBinding value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoWidgetBinding() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String scope,  String squadId,  String squadName,  bool previewEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoWidgetBinding() when $default != null:
return $default(_that.id,_that.scope,_that.squadId,_that.squadName,_that.previewEnabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String scope,  String squadId,  String squadName,  bool previewEnabled)  $default,) {final _that = this;
switch (_that) {
case _PhotoWidgetBinding():
return $default(_that.id,_that.scope,_that.squadId,_that.squadName,_that.previewEnabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String scope,  String squadId,  String squadName,  bool previewEnabled)?  $default,) {final _that = this;
switch (_that) {
case _PhotoWidgetBinding() when $default != null:
return $default(_that.id,_that.scope,_that.squadId,_that.squadName,_that.previewEnabled);case _:
  return null;

}
}

}

/// @nodoc


class _PhotoWidgetBinding implements PhotoWidgetBinding {
  const _PhotoWidgetBinding({required this.id, required this.scope, required this.squadId, required this.squadName, required this.previewEnabled});
  

@override final  String id;
@override final  String scope;
@override final  String squadId;
@override final  String squadName;
@override final  bool previewEnabled;

/// Create a copy of PhotoWidgetBinding
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoWidgetBindingCopyWith<_PhotoWidgetBinding> get copyWith => __$PhotoWidgetBindingCopyWithImpl<_PhotoWidgetBinding>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoWidgetBinding&&(identical(other.id, id) || other.id == id)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.squadName, squadName) || other.squadName == squadName)&&(identical(other.previewEnabled, previewEnabled) || other.previewEnabled == previewEnabled));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,scope,squadId,squadName,previewEnabled);
}

@override
String toString() {
    return 'PhotoWidgetBinding(id: $id, scope: $scope, squadId: $squadId, squadName: $squadName, previewEnabled: $previewEnabled)';
}


}

/// @nodoc
abstract mixin class _$PhotoWidgetBindingCopyWith<$Res> implements $PhotoWidgetBindingCopyWith<$Res> {
  factory _$PhotoWidgetBindingCopyWith(_PhotoWidgetBinding value, $Res Function(_PhotoWidgetBinding) _then) = __$PhotoWidgetBindingCopyWithImpl;
@override @useResult
$Res call({
 String id, String scope, String squadId, String squadName, bool previewEnabled
});




}
/// @nodoc
class __$PhotoWidgetBindingCopyWithImpl<$Res>
    implements _$PhotoWidgetBindingCopyWith<$Res> {
  __$PhotoWidgetBindingCopyWithImpl(this._self, this._then);

  final _PhotoWidgetBinding _self;
  final $Res Function(_PhotoWidgetBinding) _then;

/// Create a copy of PhotoWidgetBinding
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? scope = null,Object? squadId = null,Object? squadName = null,Object? previewEnabled = null,}) {
  return _then(_PhotoWidgetBinding(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,squadName: null == squadName ? _self.squadName : squadName // ignore: cast_nullable_to_non_nullable
as String,previewEnabled: null == previewEnabled ? _self.previewEnabled : previewEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$PhotoWidgetSnapshot {

 PhotoWidgetDisplay get display; String get scheme; PhotoWidgetLease? get lease; PhotoWidgetBinding? get binding; String? get messageId; DateTime? get photoExpiresAt;
/// Create a copy of PhotoWidgetSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoWidgetSnapshotCopyWith<PhotoWidgetSnapshot> get copyWith => _$PhotoWidgetSnapshotCopyWithImpl<PhotoWidgetSnapshot>(this as PhotoWidgetSnapshot, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PhotoWidgetSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoWidgetSnapshot&&(identical(other.display, _this.display) || other.display == _this.display)&&(identical(other.scheme, _this.scheme) || other.scheme == _this.scheme)&&(identical(other.lease, _this.lease) || other.lease == _this.lease)&&(identical(other.binding, _this.binding) || other.binding == _this.binding)&&(identical(other.messageId, _this.messageId) || other.messageId == _this.messageId)&&(identical(other.photoExpiresAt, _this.photoExpiresAt) || other.photoExpiresAt == _this.photoExpiresAt));
}


@override
int get hashCode {
  final _this = this as PhotoWidgetSnapshot;
  return Object.hash(runtimeType,_this.display,_this.scheme,_this.lease,_this.binding,_this.messageId,_this.photoExpiresAt);
}

@override
String toString() {
  final _this = this as PhotoWidgetSnapshot;
  return 'PhotoWidgetSnapshot(display: ${_this.display}, scheme: ${_this.scheme}, lease: ${_this.lease}, binding: ${_this.binding}, messageId: ${_this.messageId}, photoExpiresAt: ${_this.photoExpiresAt})';
}


}

/// @nodoc
abstract mixin class $PhotoWidgetSnapshotCopyWith<$Res>  {
  factory $PhotoWidgetSnapshotCopyWith(PhotoWidgetSnapshot value, $Res Function(PhotoWidgetSnapshot) _then) = _$PhotoWidgetSnapshotCopyWithImpl;
@useResult
$Res call({
 PhotoWidgetDisplay display, String scheme, PhotoWidgetLease? lease, PhotoWidgetBinding? binding, String? messageId, DateTime? photoExpiresAt
});


$PhotoWidgetLeaseCopyWith<$Res>? get lease;$PhotoWidgetBindingCopyWith<$Res>? get binding;

}
/// @nodoc
class _$PhotoWidgetSnapshotCopyWithImpl<$Res>
    implements $PhotoWidgetSnapshotCopyWith<$Res> {
  _$PhotoWidgetSnapshotCopyWithImpl(this._self, this._then);

  final PhotoWidgetSnapshot _self;
  final $Res Function(PhotoWidgetSnapshot) _then;

/// Create a copy of PhotoWidgetSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? display = null,Object? scheme = null,Object? lease = freezed,Object? binding = freezed,Object? messageId = freezed,Object? photoExpiresAt = freezed,}) {
  return _then(PhotoWidgetSnapshot(
display: null == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as PhotoWidgetDisplay,scheme: null == scheme ? _self.scheme : scheme // ignore: cast_nullable_to_non_nullable
as String,lease: freezed == lease ? _self.lease : lease // ignore: cast_nullable_to_non_nullable
as PhotoWidgetLease?,binding: freezed == binding ? _self.binding : binding // ignore: cast_nullable_to_non_nullable
as PhotoWidgetBinding?,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,photoExpiresAt: freezed == photoExpiresAt ? _self.photoExpiresAt : photoExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of PhotoWidgetSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PhotoWidgetLeaseCopyWith<$Res>? get lease {
    if (_self.lease == null) {
    return null;
  }

  return $PhotoWidgetLeaseCopyWith<$Res>(_self.lease!, (value) {
    return _then(_self.copyWith(lease: value));
  });
}/// Create a copy of PhotoWidgetSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PhotoWidgetBindingCopyWith<$Res>? get binding {
    if (_self.binding == null) {
    return null;
  }

  return $PhotoWidgetBindingCopyWith<$Res>(_self.binding!, (value) {
    return _then(_self.copyWith(binding: value));
  });
}
}


/// Adds pattern-matching-related methods to [PhotoWidgetSnapshot].
extension PhotoWidgetSnapshotPatterns on PhotoWidgetSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoWidgetSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoWidgetSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoWidgetSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _PhotoWidgetSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoWidgetSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoWidgetSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PhotoWidgetDisplay display,  String scheme,  PhotoWidgetLease? lease,  PhotoWidgetBinding? binding,  String? messageId,  DateTime? photoExpiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoWidgetSnapshot() when $default != null:
return $default(_that.display,_that.scheme,_that.lease,_that.binding,_that.messageId,_that.photoExpiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PhotoWidgetDisplay display,  String scheme,  PhotoWidgetLease? lease,  PhotoWidgetBinding? binding,  String? messageId,  DateTime? photoExpiresAt)  $default,) {final _that = this;
switch (_that) {
case _PhotoWidgetSnapshot():
return $default(_that.display,_that.scheme,_that.lease,_that.binding,_that.messageId,_that.photoExpiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PhotoWidgetDisplay display,  String scheme,  PhotoWidgetLease? lease,  PhotoWidgetBinding? binding,  String? messageId,  DateTime? photoExpiresAt)?  $default,) {final _that = this;
switch (_that) {
case _PhotoWidgetSnapshot() when $default != null:
return $default(_that.display,_that.scheme,_that.lease,_that.binding,_that.messageId,_that.photoExpiresAt);case _:
  return null;

}
}

}

/// @nodoc


class _PhotoWidgetSnapshot implements PhotoWidgetSnapshot {
  const _PhotoWidgetSnapshot({required this.display, required this.scheme, this.lease, this.binding, this.messageId, this.photoExpiresAt});
  

@override final  PhotoWidgetDisplay display;
@override final  String scheme;
@override final  PhotoWidgetLease? lease;
@override final  PhotoWidgetBinding? binding;
@override final  String? messageId;
@override final  DateTime? photoExpiresAt;

/// Create a copy of PhotoWidgetSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoWidgetSnapshotCopyWith<_PhotoWidgetSnapshot> get copyWith => __$PhotoWidgetSnapshotCopyWithImpl<_PhotoWidgetSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoWidgetSnapshot&&(identical(other.display, display) || other.display == display)&&(identical(other.scheme, scheme) || other.scheme == scheme)&&(identical(other.lease, lease) || other.lease == lease)&&(identical(other.binding, binding) || other.binding == binding)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.photoExpiresAt, photoExpiresAt) || other.photoExpiresAt == photoExpiresAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,display,scheme,lease,binding,messageId,photoExpiresAt);
}

@override
String toString() {
    return 'PhotoWidgetSnapshot(display: $display, scheme: $scheme, lease: $lease, binding: $binding, messageId: $messageId, photoExpiresAt: $photoExpiresAt)';
}


}

/// @nodoc
abstract mixin class _$PhotoWidgetSnapshotCopyWith<$Res> implements $PhotoWidgetSnapshotCopyWith<$Res> {
  factory _$PhotoWidgetSnapshotCopyWith(_PhotoWidgetSnapshot value, $Res Function(_PhotoWidgetSnapshot) _then) = __$PhotoWidgetSnapshotCopyWithImpl;
@override @useResult
$Res call({
 PhotoWidgetDisplay display, String scheme, PhotoWidgetLease? lease, PhotoWidgetBinding? binding, String? messageId, DateTime? photoExpiresAt
});


@override $PhotoWidgetLeaseCopyWith<$Res>? get lease;@override $PhotoWidgetBindingCopyWith<$Res>? get binding;

}
/// @nodoc
class __$PhotoWidgetSnapshotCopyWithImpl<$Res>
    implements _$PhotoWidgetSnapshotCopyWith<$Res> {
  __$PhotoWidgetSnapshotCopyWithImpl(this._self, this._then);

  final _PhotoWidgetSnapshot _self;
  final $Res Function(_PhotoWidgetSnapshot) _then;

/// Create a copy of PhotoWidgetSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? display = null,Object? scheme = null,Object? lease = freezed,Object? binding = freezed,Object? messageId = freezed,Object? photoExpiresAt = freezed,}) {
  return _then(_PhotoWidgetSnapshot(
display: null == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as PhotoWidgetDisplay,scheme: null == scheme ? _self.scheme : scheme // ignore: cast_nullable_to_non_nullable
as String,lease: freezed == lease ? _self.lease : lease // ignore: cast_nullable_to_non_nullable
as PhotoWidgetLease?,binding: freezed == binding ? _self.binding : binding // ignore: cast_nullable_to_non_nullable
as PhotoWidgetBinding?,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,photoExpiresAt: freezed == photoExpiresAt ? _self.photoExpiresAt : photoExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of PhotoWidgetSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PhotoWidgetLeaseCopyWith<$Res>? get lease {
    if (_self.lease == null) {
    return null;
  }

  return $PhotoWidgetLeaseCopyWith<$Res>(_self.lease!, (value) {
    return _then(_self.copyWith(lease: value));
  });
}/// Create a copy of PhotoWidgetSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PhotoWidgetBindingCopyWith<$Res>? get binding {
    if (_self.binding == null) {
    return null;
  }

  return $PhotoWidgetBindingCopyWith<$Res>(_self.binding!, (value) {
    return _then(_self.copyWith(binding: value));
  });
}
}

/// @nodoc
mixin _$PhotoWidgetEntry {

 String get squadId; String get bindingId; String get scope; String? get messageId;
/// Create a copy of PhotoWidgetEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoWidgetEntryCopyWith<PhotoWidgetEntry> get copyWith => _$PhotoWidgetEntryCopyWithImpl<PhotoWidgetEntry>(this as PhotoWidgetEntry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PhotoWidgetEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoWidgetEntry&&(identical(other.squadId, _this.squadId) || other.squadId == _this.squadId)&&(identical(other.bindingId, _this.bindingId) || other.bindingId == _this.bindingId)&&(identical(other.scope, _this.scope) || other.scope == _this.scope)&&(identical(other.messageId, _this.messageId) || other.messageId == _this.messageId));
}


@override
int get hashCode {
  final _this = this as PhotoWidgetEntry;
  return Object.hash(runtimeType,_this.squadId,_this.bindingId,_this.scope,_this.messageId);
}

@override
String toString() {
  final _this = this as PhotoWidgetEntry;
  return 'PhotoWidgetEntry(squadId: ${_this.squadId}, bindingId: ${_this.bindingId}, scope: ${_this.scope}, messageId: ${_this.messageId})';
}


}

/// @nodoc
abstract mixin class $PhotoWidgetEntryCopyWith<$Res>  {
  factory $PhotoWidgetEntryCopyWith(PhotoWidgetEntry value, $Res Function(PhotoWidgetEntry) _then) = _$PhotoWidgetEntryCopyWithImpl;
@useResult
$Res call({
 String squadId, String bindingId, String scope, String? messageId
});




}
/// @nodoc
class _$PhotoWidgetEntryCopyWithImpl<$Res>
    implements $PhotoWidgetEntryCopyWith<$Res> {
  _$PhotoWidgetEntryCopyWithImpl(this._self, this._then);

  final PhotoWidgetEntry _self;
  final $Res Function(PhotoWidgetEntry) _then;

/// Create a copy of PhotoWidgetEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? squadId = null,Object? bindingId = null,Object? scope = null,Object? messageId = freezed,}) {
  return _then(PhotoWidgetEntry(
squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,bindingId: null == bindingId ? _self.bindingId : bindingId // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PhotoWidgetEntry].
extension PhotoWidgetEntryPatterns on PhotoWidgetEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoWidgetEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoWidgetEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoWidgetEntry value)  $default,){
final _that = this;
switch (_that) {
case _PhotoWidgetEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoWidgetEntry value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoWidgetEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String squadId,  String bindingId,  String scope,  String? messageId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoWidgetEntry() when $default != null:
return $default(_that.squadId,_that.bindingId,_that.scope,_that.messageId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String squadId,  String bindingId,  String scope,  String? messageId)  $default,) {final _that = this;
switch (_that) {
case _PhotoWidgetEntry():
return $default(_that.squadId,_that.bindingId,_that.scope,_that.messageId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String squadId,  String bindingId,  String scope,  String? messageId)?  $default,) {final _that = this;
switch (_that) {
case _PhotoWidgetEntry() when $default != null:
return $default(_that.squadId,_that.bindingId,_that.scope,_that.messageId);case _:
  return null;

}
}

}

/// @nodoc


class _PhotoWidgetEntry implements PhotoWidgetEntry {
  const _PhotoWidgetEntry({required this.squadId, required this.bindingId, required this.scope, this.messageId});
  

@override final  String squadId;
@override final  String bindingId;
@override final  String scope;
@override final  String? messageId;

/// Create a copy of PhotoWidgetEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoWidgetEntryCopyWith<_PhotoWidgetEntry> get copyWith => __$PhotoWidgetEntryCopyWithImpl<_PhotoWidgetEntry>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoWidgetEntry&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.bindingId, bindingId) || other.bindingId == bindingId)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.messageId, messageId) || other.messageId == messageId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,squadId,bindingId,scope,messageId);
}

@override
String toString() {
    return 'PhotoWidgetEntry(squadId: $squadId, bindingId: $bindingId, scope: $scope, messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class _$PhotoWidgetEntryCopyWith<$Res> implements $PhotoWidgetEntryCopyWith<$Res> {
  factory _$PhotoWidgetEntryCopyWith(_PhotoWidgetEntry value, $Res Function(_PhotoWidgetEntry) _then) = __$PhotoWidgetEntryCopyWithImpl;
@override @useResult
$Res call({
 String squadId, String bindingId, String scope, String? messageId
});




}
/// @nodoc
class __$PhotoWidgetEntryCopyWithImpl<$Res>
    implements _$PhotoWidgetEntryCopyWith<$Res> {
  __$PhotoWidgetEntryCopyWithImpl(this._self, this._then);

  final _PhotoWidgetEntry _self;
  final $Res Function(_PhotoWidgetEntry) _then;

/// Create a copy of PhotoWidgetEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? squadId = null,Object? bindingId = null,Object? scope = null,Object? messageId = freezed,}) {
  return _then(_PhotoWidgetEntry(
squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,bindingId: null == bindingId ? _self.bindingId : bindingId // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
