// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fund_transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FundTransaction {

 String get id; String get fundId; String get userId; double get amount;// 正数存入，负数支出
 String? get description; String? get approvedBy; DateTime get transactionDate;// 关联信息
 String? get userNickname;
/// Create a copy of FundTransaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FundTransactionCopyWith<FundTransaction> get copyWith => _$FundTransactionCopyWithImpl<FundTransaction>(this as FundTransaction, _$identity);

  /// Serializes this FundTransaction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FundTransaction&&(identical(other.id, id) || other.id == id)&&(identical(other.fundId, fundId) || other.fundId == fundId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.description, description) || other.description == description)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.userNickname, userNickname) || other.userNickname == userNickname));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fundId,userId,amount,description,approvedBy,transactionDate,userNickname);

@override
String toString() {
  return 'FundTransaction(id: $id, fundId: $fundId, userId: $userId, amount: $amount, description: $description, approvedBy: $approvedBy, transactionDate: $transactionDate, userNickname: $userNickname)';
}


}

/// @nodoc
abstract mixin class $FundTransactionCopyWith<$Res>  {
  factory $FundTransactionCopyWith(FundTransaction value, $Res Function(FundTransaction) _then) = _$FundTransactionCopyWithImpl;
@useResult
$Res call({
 String id, String fundId, String userId, double amount, String? description, String? approvedBy, DateTime transactionDate, String? userNickname
});




}
/// @nodoc
class _$FundTransactionCopyWithImpl<$Res>
    implements $FundTransactionCopyWith<$Res> {
  _$FundTransactionCopyWithImpl(this._self, this._then);

  final FundTransaction _self;
  final $Res Function(FundTransaction) _then;

/// Create a copy of FundTransaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fundId = null,Object? userId = null,Object? amount = null,Object? description = freezed,Object? approvedBy = freezed,Object? transactionDate = null,Object? userNickname = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fundId: null == fundId ? _self.fundId : fundId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,transactionDate: null == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as DateTime,userNickname: freezed == userNickname ? _self.userNickname : userNickname // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FundTransaction].
extension FundTransactionPatterns on FundTransaction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FundTransaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FundTransaction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FundTransaction value)  $default,){
final _that = this;
switch (_that) {
case _FundTransaction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FundTransaction value)?  $default,){
final _that = this;
switch (_that) {
case _FundTransaction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String fundId,  String userId,  double amount,  String? description,  String? approvedBy,  DateTime transactionDate,  String? userNickname)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FundTransaction() when $default != null:
return $default(_that.id,_that.fundId,_that.userId,_that.amount,_that.description,_that.approvedBy,_that.transactionDate,_that.userNickname);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String fundId,  String userId,  double amount,  String? description,  String? approvedBy,  DateTime transactionDate,  String? userNickname)  $default,) {final _that = this;
switch (_that) {
case _FundTransaction():
return $default(_that.id,_that.fundId,_that.userId,_that.amount,_that.description,_that.approvedBy,_that.transactionDate,_that.userNickname);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String fundId,  String userId,  double amount,  String? description,  String? approvedBy,  DateTime transactionDate,  String? userNickname)?  $default,) {final _that = this;
switch (_that) {
case _FundTransaction() when $default != null:
return $default(_that.id,_that.fundId,_that.userId,_that.amount,_that.description,_that.approvedBy,_that.transactionDate,_that.userNickname);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FundTransaction implements FundTransaction {
  const _FundTransaction({required this.id, required this.fundId, required this.userId, required this.amount, this.description, this.approvedBy, required this.transactionDate, this.userNickname});
  factory _FundTransaction.fromJson(Map<String, dynamic> json) => _$FundTransactionFromJson(json);

@override final  String id;
@override final  String fundId;
@override final  String userId;
@override final  double amount;
// 正数存入，负数支出
@override final  String? description;
@override final  String? approvedBy;
@override final  DateTime transactionDate;
// 关联信息
@override final  String? userNickname;

/// Create a copy of FundTransaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FundTransactionCopyWith<_FundTransaction> get copyWith => __$FundTransactionCopyWithImpl<_FundTransaction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FundTransactionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FundTransaction&&(identical(other.id, id) || other.id == id)&&(identical(other.fundId, fundId) || other.fundId == fundId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.description, description) || other.description == description)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.userNickname, userNickname) || other.userNickname == userNickname));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fundId,userId,amount,description,approvedBy,transactionDate,userNickname);

@override
String toString() {
  return 'FundTransaction(id: $id, fundId: $fundId, userId: $userId, amount: $amount, description: $description, approvedBy: $approvedBy, transactionDate: $transactionDate, userNickname: $userNickname)';
}


}

/// @nodoc
abstract mixin class _$FundTransactionCopyWith<$Res> implements $FundTransactionCopyWith<$Res> {
  factory _$FundTransactionCopyWith(_FundTransaction value, $Res Function(_FundTransaction) _then) = __$FundTransactionCopyWithImpl;
@override @useResult
$Res call({
 String id, String fundId, String userId, double amount, String? description, String? approvedBy, DateTime transactionDate, String? userNickname
});




}
/// @nodoc
class __$FundTransactionCopyWithImpl<$Res>
    implements _$FundTransactionCopyWith<$Res> {
  __$FundTransactionCopyWithImpl(this._self, this._then);

  final _FundTransaction _self;
  final $Res Function(_FundTransaction) _then;

/// Create a copy of FundTransaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fundId = null,Object? userId = null,Object? amount = null,Object? description = freezed,Object? approvedBy = freezed,Object? transactionDate = null,Object? userNickname = freezed,}) {
  return _then(_FundTransaction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fundId: null == fundId ? _self.fundId : fundId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,transactionDate: null == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as DateTime,userNickname: freezed == userNickname ? _self.userNickname : userNickname // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
