// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'public_fund.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PublicFund {

 String get id; String get squadId; String get name; String get fundType;// 'travel' | 'dining' | 'team_building' | 'custom'
 double get targetAmount; double get currentAmount; String get createdBy; DateTime get createdAt;
/// Create a copy of PublicFund
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicFundCopyWith<PublicFund> get copyWith => _$PublicFundCopyWithImpl<PublicFund>(this as PublicFund, _$identity);

  /// Serializes this PublicFund to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicFund&&(identical(other.id, id) || other.id == id)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.name, name) || other.name == name)&&(identical(other.fundType, fundType) || other.fundType == fundType)&&(identical(other.targetAmount, targetAmount) || other.targetAmount == targetAmount)&&(identical(other.currentAmount, currentAmount) || other.currentAmount == currentAmount)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,squadId,name,fundType,targetAmount,currentAmount,createdBy,createdAt);

@override
String toString() {
  return 'PublicFund(id: $id, squadId: $squadId, name: $name, fundType: $fundType, targetAmount: $targetAmount, currentAmount: $currentAmount, createdBy: $createdBy, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PublicFundCopyWith<$Res>  {
  factory $PublicFundCopyWith(PublicFund value, $Res Function(PublicFund) _then) = _$PublicFundCopyWithImpl;
@useResult
$Res call({
 String id, String squadId, String name, String fundType, double targetAmount, double currentAmount, String createdBy, DateTime createdAt
});




}
/// @nodoc
class _$PublicFundCopyWithImpl<$Res>
    implements $PublicFundCopyWith<$Res> {
  _$PublicFundCopyWithImpl(this._self, this._then);

  final PublicFund _self;
  final $Res Function(PublicFund) _then;

/// Create a copy of PublicFund
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? squadId = null,Object? name = null,Object? fundType = null,Object? targetAmount = null,Object? currentAmount = null,Object? createdBy = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fundType: null == fundType ? _self.fundType : fundType // ignore: cast_nullable_to_non_nullable
as String,targetAmount: null == targetAmount ? _self.targetAmount : targetAmount // ignore: cast_nullable_to_non_nullable
as double,currentAmount: null == currentAmount ? _self.currentAmount : currentAmount // ignore: cast_nullable_to_non_nullable
as double,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [PublicFund].
extension PublicFundPatterns on PublicFund {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicFund value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicFund() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicFund value)  $default,){
final _that = this;
switch (_that) {
case _PublicFund():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicFund value)?  $default,){
final _that = this;
switch (_that) {
case _PublicFund() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String squadId,  String name,  String fundType,  double targetAmount,  double currentAmount,  String createdBy,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicFund() when $default != null:
return $default(_that.id,_that.squadId,_that.name,_that.fundType,_that.targetAmount,_that.currentAmount,_that.createdBy,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String squadId,  String name,  String fundType,  double targetAmount,  double currentAmount,  String createdBy,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _PublicFund():
return $default(_that.id,_that.squadId,_that.name,_that.fundType,_that.targetAmount,_that.currentAmount,_that.createdBy,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String squadId,  String name,  String fundType,  double targetAmount,  double currentAmount,  String createdBy,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _PublicFund() when $default != null:
return $default(_that.id,_that.squadId,_that.name,_that.fundType,_that.targetAmount,_that.currentAmount,_that.createdBy,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicFund implements PublicFund {
  const _PublicFund({required this.id, required this.squadId, required this.name, required this.fundType, this.targetAmount = 0, this.currentAmount = 0, required this.createdBy, required this.createdAt});
  factory _PublicFund.fromJson(Map<String, dynamic> json) => _$PublicFundFromJson(json);

@override final  String id;
@override final  String squadId;
@override final  String name;
@override final  String fundType;
// 'travel' | 'dining' | 'team_building' | 'custom'
@override@JsonKey() final  double targetAmount;
@override@JsonKey() final  double currentAmount;
@override final  String createdBy;
@override final  DateTime createdAt;

/// Create a copy of PublicFund
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicFundCopyWith<_PublicFund> get copyWith => __$PublicFundCopyWithImpl<_PublicFund>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicFundToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicFund&&(identical(other.id, id) || other.id == id)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.name, name) || other.name == name)&&(identical(other.fundType, fundType) || other.fundType == fundType)&&(identical(other.targetAmount, targetAmount) || other.targetAmount == targetAmount)&&(identical(other.currentAmount, currentAmount) || other.currentAmount == currentAmount)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,squadId,name,fundType,targetAmount,currentAmount,createdBy,createdAt);

@override
String toString() {
  return 'PublicFund(id: $id, squadId: $squadId, name: $name, fundType: $fundType, targetAmount: $targetAmount, currentAmount: $currentAmount, createdBy: $createdBy, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PublicFundCopyWith<$Res> implements $PublicFundCopyWith<$Res> {
  factory _$PublicFundCopyWith(_PublicFund value, $Res Function(_PublicFund) _then) = __$PublicFundCopyWithImpl;
@override @useResult
$Res call({
 String id, String squadId, String name, String fundType, double targetAmount, double currentAmount, String createdBy, DateTime createdAt
});




}
/// @nodoc
class __$PublicFundCopyWithImpl<$Res>
    implements _$PublicFundCopyWith<$Res> {
  __$PublicFundCopyWithImpl(this._self, this._then);

  final _PublicFund _self;
  final $Res Function(_PublicFund) _then;

/// Create a copy of PublicFund
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? squadId = null,Object? name = null,Object? fundType = null,Object? targetAmount = null,Object? currentAmount = null,Object? createdBy = null,Object? createdAt = null,}) {
  return _then(_PublicFund(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fundType: null == fundType ? _self.fundType : fundType // ignore: cast_nullable_to_non_nullable
as String,targetAmount: null == targetAmount ? _self.targetAmount : targetAmount // ignore: cast_nullable_to_non_nullable
as double,currentAmount: null == currentAmount ? _self.currentAmount : currentAmount // ignore: cast_nullable_to_non_nullable
as double,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
