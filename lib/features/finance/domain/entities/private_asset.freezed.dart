// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'private_asset.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PrivateAsset {

 String get id; String get userId; String get assetType;// 'savings' | 'stock' | 'fund' | 'other'
 String get name; double get amount; String? get note; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of PrivateAsset
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PrivateAssetCopyWith<PrivateAsset> get copyWith => _$PrivateAssetCopyWithImpl<PrivateAsset>(this as PrivateAsset, _$identity);

  /// Serializes this PrivateAsset to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PrivateAsset&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assetType, assetType) || other.assetType == assetType)&&(identical(other.name, name) || other.name == name)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,assetType,name,amount,note,createdAt,updatedAt);

@override
String toString() {
  return 'PrivateAsset(id: $id, userId: $userId, assetType: $assetType, name: $name, amount: $amount, note: $note, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $PrivateAssetCopyWith<$Res>  {
  factory $PrivateAssetCopyWith(PrivateAsset value, $Res Function(PrivateAsset) _then) = _$PrivateAssetCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String assetType, String name, double amount, String? note, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$PrivateAssetCopyWithImpl<$Res>
    implements $PrivateAssetCopyWith<$Res> {
  _$PrivateAssetCopyWithImpl(this._self, this._then);

  final PrivateAsset _self;
  final $Res Function(PrivateAsset) _then;

/// Create a copy of PrivateAsset
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? assetType = null,Object? name = null,Object? amount = null,Object? note = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assetType: null == assetType ? _self.assetType : assetType // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [PrivateAsset].
extension PrivateAssetPatterns on PrivateAsset {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PrivateAsset value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PrivateAsset() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PrivateAsset value)  $default,){
final _that = this;
switch (_that) {
case _PrivateAsset():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PrivateAsset value)?  $default,){
final _that = this;
switch (_that) {
case _PrivateAsset() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String assetType,  String name,  double amount,  String? note,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PrivateAsset() when $default != null:
return $default(_that.id,_that.userId,_that.assetType,_that.name,_that.amount,_that.note,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String assetType,  String name,  double amount,  String? note,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _PrivateAsset():
return $default(_that.id,_that.userId,_that.assetType,_that.name,_that.amount,_that.note,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String assetType,  String name,  double amount,  String? note,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _PrivateAsset() when $default != null:
return $default(_that.id,_that.userId,_that.assetType,_that.name,_that.amount,_that.note,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PrivateAsset implements PrivateAsset {
  const _PrivateAsset({required this.id, required this.userId, required this.assetType, required this.name, this.amount = 0, this.note, required this.createdAt, required this.updatedAt});
  factory _PrivateAsset.fromJson(Map<String, dynamic> json) => _$PrivateAssetFromJson(json);

@override final  String id;
@override final  String userId;
@override final  String assetType;
// 'savings' | 'stock' | 'fund' | 'other'
@override final  String name;
@override@JsonKey() final  double amount;
@override final  String? note;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of PrivateAsset
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PrivateAssetCopyWith<_PrivateAsset> get copyWith => __$PrivateAssetCopyWithImpl<_PrivateAsset>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PrivateAssetToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PrivateAsset&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assetType, assetType) || other.assetType == assetType)&&(identical(other.name, name) || other.name == name)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,assetType,name,amount,note,createdAt,updatedAt);

@override
String toString() {
  return 'PrivateAsset(id: $id, userId: $userId, assetType: $assetType, name: $name, amount: $amount, note: $note, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$PrivateAssetCopyWith<$Res> implements $PrivateAssetCopyWith<$Res> {
  factory _$PrivateAssetCopyWith(_PrivateAsset value, $Res Function(_PrivateAsset) _then) = __$PrivateAssetCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String assetType, String name, double amount, String? note, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$PrivateAssetCopyWithImpl<$Res>
    implements _$PrivateAssetCopyWith<$Res> {
  __$PrivateAssetCopyWithImpl(this._self, this._then);

  final _PrivateAsset _self;
  final $Res Function(_PrivateAsset) _then;

/// Create a copy of PrivateAsset
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? assetType = null,Object? name = null,Object? amount = null,Object? note = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_PrivateAsset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assetType: null == assetType ? _self.assetType : assetType // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
