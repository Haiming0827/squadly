// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DailyTask {

 String get id; String get squadId; String get title; String get taskType; double? get targetValue; String? get targetUnit; List<int> get recurringDays; bool get isActive; DateTime get createdAt;
/// Create a copy of DailyTask
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyTaskCopyWith<DailyTask> get copyWith => _$DailyTaskCopyWithImpl<DailyTask>(this as DailyTask, _$identity);

  /// Serializes this DailyTask to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DailyTask;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyTask&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.squadId, _this.squadId) || other.squadId == _this.squadId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.taskType, _this.taskType) || other.taskType == _this.taskType)&&(identical(other.targetValue, _this.targetValue) || other.targetValue == _this.targetValue)&&(identical(other.targetUnit, _this.targetUnit) || other.targetUnit == _this.targetUnit)&&const DeepCollectionEquality().equals(other.recurringDays, _this.recurringDays)&&(identical(other.isActive, _this.isActive) || other.isActive == _this.isActive)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DailyTask;
  return Object.hash(runtimeType,_this.id,_this.squadId,_this.title,_this.taskType,_this.targetValue,_this.targetUnit,const DeepCollectionEquality().hash(_this.recurringDays),_this.isActive,_this.createdAt);
}

@override
String toString() {
  final _this = this as DailyTask;
  return 'DailyTask(id: ${_this.id}, squadId: ${_this.squadId}, title: ${_this.title}, taskType: ${_this.taskType}, targetValue: ${_this.targetValue}, targetUnit: ${_this.targetUnit}, recurringDays: ${_this.recurringDays}, isActive: ${_this.isActive}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $DailyTaskCopyWith<$Res>  {
  factory $DailyTaskCopyWith(DailyTask value, $Res Function(DailyTask) _then) = _$DailyTaskCopyWithImpl;
@useResult
$Res call({
 String id, String squadId, String title, String taskType, double? targetValue, String? targetUnit, List<int> recurringDays, bool isActive, DateTime createdAt
});




}
/// @nodoc
class _$DailyTaskCopyWithImpl<$Res>
    implements $DailyTaskCopyWith<$Res> {
  _$DailyTaskCopyWithImpl(this._self, this._then);

  final DailyTask _self;
  final $Res Function(DailyTask) _then;

/// Create a copy of DailyTask
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? squadId = null,Object? title = null,Object? taskType = null,Object? targetValue = freezed,Object? targetUnit = freezed,Object? recurringDays = null,Object? isActive = null,Object? createdAt = null,}) {
  return _then(DailyTask(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,taskType: null == taskType ? _self.taskType : taskType // ignore: cast_nullable_to_non_nullable
as String,targetValue: freezed == targetValue ? _self.targetValue : targetValue // ignore: cast_nullable_to_non_nullable
as double?,targetUnit: freezed == targetUnit ? _self.targetUnit : targetUnit // ignore: cast_nullable_to_non_nullable
as String?,recurringDays: null == recurringDays ? _self.recurringDays : recurringDays // ignore: cast_nullable_to_non_nullable
as List<int>,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyTask].
extension DailyTaskPatterns on DailyTask {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyTask value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyTask() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyTask value)  $default,){
final _that = this;
switch (_that) {
case _DailyTask():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyTask value)?  $default,){
final _that = this;
switch (_that) {
case _DailyTask() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String squadId,  String title,  String taskType,  double? targetValue,  String? targetUnit,  List<int> recurringDays,  bool isActive,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyTask() when $default != null:
return $default(_that.id,_that.squadId,_that.title,_that.taskType,_that.targetValue,_that.targetUnit,_that.recurringDays,_that.isActive,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String squadId,  String title,  String taskType,  double? targetValue,  String? targetUnit,  List<int> recurringDays,  bool isActive,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _DailyTask():
return $default(_that.id,_that.squadId,_that.title,_that.taskType,_that.targetValue,_that.targetUnit,_that.recurringDays,_that.isActive,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String squadId,  String title,  String taskType,  double? targetValue,  String? targetUnit,  List<int> recurringDays,  bool isActive,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _DailyTask() when $default != null:
return $default(_that.id,_that.squadId,_that.title,_that.taskType,_that.targetValue,_that.targetUnit,_that.recurringDays,_that.isActive,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DailyTask implements DailyTask {
  const _DailyTask({required this.id, required this.squadId, required this.title, required this.taskType, this.targetValue, this.targetUnit,  List<int> recurringDays = const [], this.isActive = true, required this.createdAt}): _recurringDays = recurringDays;
  factory _DailyTask.fromJson(Map<String, dynamic> json) => _$DailyTaskFromJson(json);

@override final  String id;
@override final  String squadId;
@override final  String title;
@override final  String taskType;
@override final  double? targetValue;
@override final  String? targetUnit;
 final  List<int> _recurringDays;
@override@JsonKey() List<int> get recurringDays {
  if (_recurringDays is EqualUnmodifiableListView) return _recurringDays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recurringDays);
}

@override@JsonKey() final  bool isActive;
@override final  DateTime createdAt;

/// Create a copy of DailyTask
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyTaskCopyWith<_DailyTask> get copyWith => __$DailyTaskCopyWithImpl<_DailyTask>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DailyTaskToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyTask&&(identical(other.id, id) || other.id == id)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.title, title) || other.title == title)&&(identical(other.taskType, taskType) || other.taskType == taskType)&&(identical(other.targetValue, targetValue) || other.targetValue == targetValue)&&(identical(other.targetUnit, targetUnit) || other.targetUnit == targetUnit)&&const DeepCollectionEquality().equals(other.recurringDays, _recurringDays)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,squadId,title,taskType,targetValue,targetUnit,const DeepCollectionEquality().hash(_recurringDays),isActive,createdAt);
}

@override
String toString() {
    return 'DailyTask(id: $id, squadId: $squadId, title: $title, taskType: $taskType, targetValue: $targetValue, targetUnit: $targetUnit, recurringDays: $recurringDays, isActive: $isActive, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$DailyTaskCopyWith<$Res> implements $DailyTaskCopyWith<$Res> {
  factory _$DailyTaskCopyWith(_DailyTask value, $Res Function(_DailyTask) _then) = __$DailyTaskCopyWithImpl;
@override @useResult
$Res call({
 String id, String squadId, String title, String taskType, double? targetValue, String? targetUnit, List<int> recurringDays, bool isActive, DateTime createdAt
});




}
/// @nodoc
class __$DailyTaskCopyWithImpl<$Res>
    implements _$DailyTaskCopyWith<$Res> {
  __$DailyTaskCopyWithImpl(this._self, this._then);

  final _DailyTask _self;
  final $Res Function(_DailyTask) _then;

/// Create a copy of DailyTask
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? squadId = null,Object? title = null,Object? taskType = null,Object? targetValue = freezed,Object? targetUnit = freezed,Object? recurringDays = null,Object? isActive = null,Object? createdAt = null,}) {
  return _then(_DailyTask(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,taskType: null == taskType ? _self.taskType : taskType // ignore: cast_nullable_to_non_nullable
as String,targetValue: freezed == targetValue ? _self.targetValue : targetValue // ignore: cast_nullable_to_non_nullable
as double?,targetUnit: freezed == targetUnit ? _self.targetUnit : targetUnit // ignore: cast_nullable_to_non_nullable
as String?,recurringDays: null == recurringDays ? _self._recurringDays : recurringDays // ignore: cast_nullable_to_non_nullable
as List<int>,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
