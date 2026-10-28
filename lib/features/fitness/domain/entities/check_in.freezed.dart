// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'check_in.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CheckIn {

 String get id; String get taskId; String get userId; String get squadId; double? get value; String? get note; DateTime get checkedAt; DateTime get createdAt; String? get userNickname; String? get taskTitle;
/// Create a copy of CheckIn
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CheckInCopyWith<CheckIn> get copyWith => _$CheckInCopyWithImpl<CheckIn>(this as CheckIn, _$identity);

  /// Serializes this CheckIn to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CheckIn;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CheckIn&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.taskId, _this.taskId) || other.taskId == _this.taskId)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.squadId, _this.squadId) || other.squadId == _this.squadId)&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.note, _this.note) || other.note == _this.note)&&(identical(other.checkedAt, _this.checkedAt) || other.checkedAt == _this.checkedAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.userNickname, _this.userNickname) || other.userNickname == _this.userNickname)&&(identical(other.taskTitle, _this.taskTitle) || other.taskTitle == _this.taskTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CheckIn;
  return Object.hash(runtimeType,_this.id,_this.taskId,_this.userId,_this.squadId,_this.value,_this.note,_this.checkedAt,_this.createdAt,_this.userNickname,_this.taskTitle);
}

@override
String toString() {
  final _this = this as CheckIn;
  return 'CheckIn(id: ${_this.id}, taskId: ${_this.taskId}, userId: ${_this.userId}, squadId: ${_this.squadId}, value: ${_this.value}, note: ${_this.note}, checkedAt: ${_this.checkedAt}, createdAt: ${_this.createdAt}, userNickname: ${_this.userNickname}, taskTitle: ${_this.taskTitle})';
}


}

/// @nodoc
abstract mixin class $CheckInCopyWith<$Res>  {
  factory $CheckInCopyWith(CheckIn value, $Res Function(CheckIn) _then) = _$CheckInCopyWithImpl;
@useResult
$Res call({
 String id, String taskId, String userId, String squadId, double? value, String? note, DateTime checkedAt, DateTime createdAt, String? userNickname, String? taskTitle
});




}
/// @nodoc
class _$CheckInCopyWithImpl<$Res>
    implements $CheckInCopyWith<$Res> {
  _$CheckInCopyWithImpl(this._self, this._then);

  final CheckIn _self;
  final $Res Function(CheckIn) _then;

/// Create a copy of CheckIn
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? taskId = null,Object? userId = null,Object? squadId = null,Object? value = freezed,Object? note = freezed,Object? checkedAt = null,Object? createdAt = null,Object? userNickname = freezed,Object? taskTitle = freezed,}) {
  return _then(CheckIn(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,checkedAt: null == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,userNickname: freezed == userNickname ? _self.userNickname : userNickname // ignore: cast_nullable_to_non_nullable
as String?,taskTitle: freezed == taskTitle ? _self.taskTitle : taskTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CheckIn].
extension CheckInPatterns on CheckIn {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CheckIn value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CheckIn() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CheckIn value)  $default,){
final _that = this;
switch (_that) {
case _CheckIn():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CheckIn value)?  $default,){
final _that = this;
switch (_that) {
case _CheckIn() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String taskId,  String userId,  String squadId,  double? value,  String? note,  DateTime checkedAt,  DateTime createdAt,  String? userNickname,  String? taskTitle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CheckIn() when $default != null:
return $default(_that.id,_that.taskId,_that.userId,_that.squadId,_that.value,_that.note,_that.checkedAt,_that.createdAt,_that.userNickname,_that.taskTitle);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String taskId,  String userId,  String squadId,  double? value,  String? note,  DateTime checkedAt,  DateTime createdAt,  String? userNickname,  String? taskTitle)  $default,) {final _that = this;
switch (_that) {
case _CheckIn():
return $default(_that.id,_that.taskId,_that.userId,_that.squadId,_that.value,_that.note,_that.checkedAt,_that.createdAt,_that.userNickname,_that.taskTitle);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String taskId,  String userId,  String squadId,  double? value,  String? note,  DateTime checkedAt,  DateTime createdAt,  String? userNickname,  String? taskTitle)?  $default,) {final _that = this;
switch (_that) {
case _CheckIn() when $default != null:
return $default(_that.id,_that.taskId,_that.userId,_that.squadId,_that.value,_that.note,_that.checkedAt,_that.createdAt,_that.userNickname,_that.taskTitle);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CheckIn implements CheckIn {
  const _CheckIn({required this.id, required this.taskId, required this.userId, required this.squadId, this.value, this.note, required this.checkedAt, required this.createdAt, this.userNickname, this.taskTitle});
  factory _CheckIn.fromJson(Map<String, dynamic> json) => _$CheckInFromJson(json);

@override final  String id;
@override final  String taskId;
@override final  String userId;
@override final  String squadId;
@override final  double? value;
@override final  String? note;
@override final  DateTime checkedAt;
@override final  DateTime createdAt;
@override final  String? userNickname;
@override final  String? taskTitle;

/// Create a copy of CheckIn
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CheckInCopyWith<_CheckIn> get copyWith => __$CheckInCopyWithImpl<_CheckIn>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CheckInToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CheckIn&&(identical(other.id, id) || other.id == id)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.value, value) || other.value == value)&&(identical(other.note, note) || other.note == note)&&(identical(other.checkedAt, checkedAt) || other.checkedAt == checkedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.userNickname, userNickname) || other.userNickname == userNickname)&&(identical(other.taskTitle, taskTitle) || other.taskTitle == taskTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,taskId,userId,squadId,value,note,checkedAt,createdAt,userNickname,taskTitle);
}

@override
String toString() {
    return 'CheckIn(id: $id, taskId: $taskId, userId: $userId, squadId: $squadId, value: $value, note: $note, checkedAt: $checkedAt, createdAt: $createdAt, userNickname: $userNickname, taskTitle: $taskTitle)';
}


}

/// @nodoc
abstract mixin class _$CheckInCopyWith<$Res> implements $CheckInCopyWith<$Res> {
  factory _$CheckInCopyWith(_CheckIn value, $Res Function(_CheckIn) _then) = __$CheckInCopyWithImpl;
@override @useResult
$Res call({
 String id, String taskId, String userId, String squadId, double? value, String? note, DateTime checkedAt, DateTime createdAt, String? userNickname, String? taskTitle
});




}
/// @nodoc
class __$CheckInCopyWithImpl<$Res>
    implements _$CheckInCopyWith<$Res> {
  __$CheckInCopyWithImpl(this._self, this._then);

  final _CheckIn _self;
  final $Res Function(_CheckIn) _then;

/// Create a copy of CheckIn
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? taskId = null,Object? userId = null,Object? squadId = null,Object? value = freezed,Object? note = freezed,Object? checkedAt = null,Object? createdAt = null,Object? userNickname = freezed,Object? taskTitle = freezed,}) {
  return _then(_CheckIn(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,checkedAt: null == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,userNickname: freezed == userNickname ? _self.userNickname : userNickname // ignore: cast_nullable_to_non_nullable
as String?,taskTitle: freezed == taskTitle ? _self.taskTitle : taskTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
