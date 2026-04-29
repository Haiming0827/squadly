// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shared_expense.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SharedExpense {

 String get id; String get squadId; String get paidBy; double get amount; String get category;// 'dining' | 'transport' | 'entertainment' | 'other'
 String? get description; DateTime get expenseDate; bool get needsApproval; int get approvedCount; DateTime get createdAt;// 关联信息
 String? get paidByNickname;
/// Create a copy of SharedExpense
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SharedExpenseCopyWith<SharedExpense> get copyWith => _$SharedExpenseCopyWithImpl<SharedExpense>(this as SharedExpense, _$identity);

  /// Serializes this SharedExpense to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SharedExpense&&(identical(other.id, id) || other.id == id)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.paidBy, paidBy) || other.paidBy == paidBy)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.category, category) || other.category == category)&&(identical(other.description, description) || other.description == description)&&(identical(other.expenseDate, expenseDate) || other.expenseDate == expenseDate)&&(identical(other.needsApproval, needsApproval) || other.needsApproval == needsApproval)&&(identical(other.approvedCount, approvedCount) || other.approvedCount == approvedCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.paidByNickname, paidByNickname) || other.paidByNickname == paidByNickname));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,squadId,paidBy,amount,category,description,expenseDate,needsApproval,approvedCount,createdAt,paidByNickname);

@override
String toString() {
  return 'SharedExpense(id: $id, squadId: $squadId, paidBy: $paidBy, amount: $amount, category: $category, description: $description, expenseDate: $expenseDate, needsApproval: $needsApproval, approvedCount: $approvedCount, createdAt: $createdAt, paidByNickname: $paidByNickname)';
}


}

/// @nodoc
abstract mixin class $SharedExpenseCopyWith<$Res>  {
  factory $SharedExpenseCopyWith(SharedExpense value, $Res Function(SharedExpense) _then) = _$SharedExpenseCopyWithImpl;
@useResult
$Res call({
 String id, String squadId, String paidBy, double amount, String category, String? description, DateTime expenseDate, bool needsApproval, int approvedCount, DateTime createdAt, String? paidByNickname
});




}
/// @nodoc
class _$SharedExpenseCopyWithImpl<$Res>
    implements $SharedExpenseCopyWith<$Res> {
  _$SharedExpenseCopyWithImpl(this._self, this._then);

  final SharedExpense _self;
  final $Res Function(SharedExpense) _then;

/// Create a copy of SharedExpense
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? squadId = null,Object? paidBy = null,Object? amount = null,Object? category = null,Object? description = freezed,Object? expenseDate = null,Object? needsApproval = null,Object? approvedCount = null,Object? createdAt = null,Object? paidByNickname = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,paidBy: null == paidBy ? _self.paidBy : paidBy // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,expenseDate: null == expenseDate ? _self.expenseDate : expenseDate // ignore: cast_nullable_to_non_nullable
as DateTime,needsApproval: null == needsApproval ? _self.needsApproval : needsApproval // ignore: cast_nullable_to_non_nullable
as bool,approvedCount: null == approvedCount ? _self.approvedCount : approvedCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,paidByNickname: freezed == paidByNickname ? _self.paidByNickname : paidByNickname // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SharedExpense].
extension SharedExpensePatterns on SharedExpense {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SharedExpense value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SharedExpense() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SharedExpense value)  $default,){
final _that = this;
switch (_that) {
case _SharedExpense():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SharedExpense value)?  $default,){
final _that = this;
switch (_that) {
case _SharedExpense() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String squadId,  String paidBy,  double amount,  String category,  String? description,  DateTime expenseDate,  bool needsApproval,  int approvedCount,  DateTime createdAt,  String? paidByNickname)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SharedExpense() when $default != null:
return $default(_that.id,_that.squadId,_that.paidBy,_that.amount,_that.category,_that.description,_that.expenseDate,_that.needsApproval,_that.approvedCount,_that.createdAt,_that.paidByNickname);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String squadId,  String paidBy,  double amount,  String category,  String? description,  DateTime expenseDate,  bool needsApproval,  int approvedCount,  DateTime createdAt,  String? paidByNickname)  $default,) {final _that = this;
switch (_that) {
case _SharedExpense():
return $default(_that.id,_that.squadId,_that.paidBy,_that.amount,_that.category,_that.description,_that.expenseDate,_that.needsApproval,_that.approvedCount,_that.createdAt,_that.paidByNickname);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String squadId,  String paidBy,  double amount,  String category,  String? description,  DateTime expenseDate,  bool needsApproval,  int approvedCount,  DateTime createdAt,  String? paidByNickname)?  $default,) {final _that = this;
switch (_that) {
case _SharedExpense() when $default != null:
return $default(_that.id,_that.squadId,_that.paidBy,_that.amount,_that.category,_that.description,_that.expenseDate,_that.needsApproval,_that.approvedCount,_that.createdAt,_that.paidByNickname);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SharedExpense implements SharedExpense {
  const _SharedExpense({required this.id, required this.squadId, required this.paidBy, required this.amount, required this.category, this.description, required this.expenseDate, this.needsApproval = false, this.approvedCount = 0, required this.createdAt, this.paidByNickname});
  factory _SharedExpense.fromJson(Map<String, dynamic> json) => _$SharedExpenseFromJson(json);

@override final  String id;
@override final  String squadId;
@override final  String paidBy;
@override final  double amount;
@override final  String category;
// 'dining' | 'transport' | 'entertainment' | 'other'
@override final  String? description;
@override final  DateTime expenseDate;
@override@JsonKey() final  bool needsApproval;
@override@JsonKey() final  int approvedCount;
@override final  DateTime createdAt;
// 关联信息
@override final  String? paidByNickname;

/// Create a copy of SharedExpense
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SharedExpenseCopyWith<_SharedExpense> get copyWith => __$SharedExpenseCopyWithImpl<_SharedExpense>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SharedExpenseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SharedExpense&&(identical(other.id, id) || other.id == id)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.paidBy, paidBy) || other.paidBy == paidBy)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.category, category) || other.category == category)&&(identical(other.description, description) || other.description == description)&&(identical(other.expenseDate, expenseDate) || other.expenseDate == expenseDate)&&(identical(other.needsApproval, needsApproval) || other.needsApproval == needsApproval)&&(identical(other.approvedCount, approvedCount) || other.approvedCount == approvedCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.paidByNickname, paidByNickname) || other.paidByNickname == paidByNickname));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,squadId,paidBy,amount,category,description,expenseDate,needsApproval,approvedCount,createdAt,paidByNickname);

@override
String toString() {
  return 'SharedExpense(id: $id, squadId: $squadId, paidBy: $paidBy, amount: $amount, category: $category, description: $description, expenseDate: $expenseDate, needsApproval: $needsApproval, approvedCount: $approvedCount, createdAt: $createdAt, paidByNickname: $paidByNickname)';
}


}

/// @nodoc
abstract mixin class _$SharedExpenseCopyWith<$Res> implements $SharedExpenseCopyWith<$Res> {
  factory _$SharedExpenseCopyWith(_SharedExpense value, $Res Function(_SharedExpense) _then) = __$SharedExpenseCopyWithImpl;
@override @useResult
$Res call({
 String id, String squadId, String paidBy, double amount, String category, String? description, DateTime expenseDate, bool needsApproval, int approvedCount, DateTime createdAt, String? paidByNickname
});




}
/// @nodoc
class __$SharedExpenseCopyWithImpl<$Res>
    implements _$SharedExpenseCopyWith<$Res> {
  __$SharedExpenseCopyWithImpl(this._self, this._then);

  final _SharedExpense _self;
  final $Res Function(_SharedExpense) _then;

/// Create a copy of SharedExpense
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? squadId = null,Object? paidBy = null,Object? amount = null,Object? category = null,Object? description = freezed,Object? expenseDate = null,Object? needsApproval = null,Object? approvedCount = null,Object? createdAt = null,Object? paidByNickname = freezed,}) {
  return _then(_SharedExpense(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,paidBy: null == paidBy ? _self.paidBy : paidBy // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,expenseDate: null == expenseDate ? _self.expenseDate : expenseDate // ignore: cast_nullable_to_non_nullable
as DateTime,needsApproval: null == needsApproval ? _self.needsApproval : needsApproval // ignore: cast_nullable_to_non_nullable
as bool,approvedCount: null == approvedCount ? _self.approvedCount : approvedCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,paidByNickname: freezed == paidByNickname ? _self.paidByNickname : paidByNickname // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
