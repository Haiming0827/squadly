// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation_preference.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConversationPreference {

 String get squadId; String get remark; DateTime? get pinnedAt; DateTime? get lastOpenedAt; int get recentOpenCount;
/// Create a copy of ConversationPreference
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationPreferenceCopyWith<ConversationPreference> get copyWith => _$ConversationPreferenceCopyWithImpl<ConversationPreference>(this as ConversationPreference, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ConversationPreference;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationPreference&&(identical(other.squadId, _this.squadId) || other.squadId == _this.squadId)&&(identical(other.remark, _this.remark) || other.remark == _this.remark)&&(identical(other.pinnedAt, _this.pinnedAt) || other.pinnedAt == _this.pinnedAt)&&(identical(other.lastOpenedAt, _this.lastOpenedAt) || other.lastOpenedAt == _this.lastOpenedAt)&&(identical(other.recentOpenCount, _this.recentOpenCount) || other.recentOpenCount == _this.recentOpenCount));
}


@override
int get hashCode {
  final _this = this as ConversationPreference;
  return Object.hash(runtimeType,_this.squadId,_this.remark,_this.pinnedAt,_this.lastOpenedAt,_this.recentOpenCount);
}

@override
String toString() {
  final _this = this as ConversationPreference;
  return 'ConversationPreference(squadId: ${_this.squadId}, remark: ${_this.remark}, pinnedAt: ${_this.pinnedAt}, lastOpenedAt: ${_this.lastOpenedAt}, recentOpenCount: ${_this.recentOpenCount})';
}


}

/// @nodoc
abstract mixin class $ConversationPreferenceCopyWith<$Res>  {
  factory $ConversationPreferenceCopyWith(ConversationPreference value, $Res Function(ConversationPreference) _then) = _$ConversationPreferenceCopyWithImpl;
@useResult
$Res call({
 String squadId, String remark, DateTime? pinnedAt, DateTime? lastOpenedAt, int recentOpenCount
});




}
/// @nodoc
class _$ConversationPreferenceCopyWithImpl<$Res>
    implements $ConversationPreferenceCopyWith<$Res> {
  _$ConversationPreferenceCopyWithImpl(this._self, this._then);

  final ConversationPreference _self;
  final $Res Function(ConversationPreference) _then;

/// Create a copy of ConversationPreference
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? squadId = null,Object? remark = null,Object? pinnedAt = freezed,Object? lastOpenedAt = freezed,Object? recentOpenCount = null,}) {
  return _then(ConversationPreference(
squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,remark: null == remark ? _self.remark : remark // ignore: cast_nullable_to_non_nullable
as String,pinnedAt: freezed == pinnedAt ? _self.pinnedAt : pinnedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastOpenedAt: freezed == lastOpenedAt ? _self.lastOpenedAt : lastOpenedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,recentOpenCount: null == recentOpenCount ? _self.recentOpenCount : recentOpenCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ConversationPreference].
extension ConversationPreferencePatterns on ConversationPreference {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationPreference value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationPreference() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationPreference value)  $default,){
final _that = this;
switch (_that) {
case _ConversationPreference():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationPreference value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationPreference() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String squadId,  String remark,  DateTime? pinnedAt,  DateTime? lastOpenedAt,  int recentOpenCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationPreference() when $default != null:
return $default(_that.squadId,_that.remark,_that.pinnedAt,_that.lastOpenedAt,_that.recentOpenCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String squadId,  String remark,  DateTime? pinnedAt,  DateTime? lastOpenedAt,  int recentOpenCount)  $default,) {final _that = this;
switch (_that) {
case _ConversationPreference():
return $default(_that.squadId,_that.remark,_that.pinnedAt,_that.lastOpenedAt,_that.recentOpenCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String squadId,  String remark,  DateTime? pinnedAt,  DateTime? lastOpenedAt,  int recentOpenCount)?  $default,) {final _that = this;
switch (_that) {
case _ConversationPreference() when $default != null:
return $default(_that.squadId,_that.remark,_that.pinnedAt,_that.lastOpenedAt,_that.recentOpenCount);case _:
  return null;

}
}

}

/// @nodoc


class _ConversationPreference extends ConversationPreference {
  const _ConversationPreference({required this.squadId, this.remark = '', this.pinnedAt, this.lastOpenedAt, this.recentOpenCount = 0}): super._();


@override final  String squadId;
@override@JsonKey() final  String remark;
@override final  DateTime? pinnedAt;
@override final  DateTime? lastOpenedAt;
@override@JsonKey() final  int recentOpenCount;

/// Create a copy of ConversationPreference
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationPreferenceCopyWith<_ConversationPreference> get copyWith => __$ConversationPreferenceCopyWithImpl<_ConversationPreference>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationPreference&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.remark, remark) || other.remark == remark)&&(identical(other.pinnedAt, pinnedAt) || other.pinnedAt == pinnedAt)&&(identical(other.lastOpenedAt, lastOpenedAt) || other.lastOpenedAt == lastOpenedAt)&&(identical(other.recentOpenCount, recentOpenCount) || other.recentOpenCount == recentOpenCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,squadId,remark,pinnedAt,lastOpenedAt,recentOpenCount);
}

@override
String toString() {
    return 'ConversationPreference(squadId: $squadId, remark: $remark, pinnedAt: $pinnedAt, lastOpenedAt: $lastOpenedAt, recentOpenCount: $recentOpenCount)';
}


}

/// @nodoc
abstract mixin class _$ConversationPreferenceCopyWith<$Res> implements $ConversationPreferenceCopyWith<$Res> {
  factory _$ConversationPreferenceCopyWith(_ConversationPreference value, $Res Function(_ConversationPreference) _then) = __$ConversationPreferenceCopyWithImpl;
@override @useResult
$Res call({
 String squadId, String remark, DateTime? pinnedAt, DateTime? lastOpenedAt, int recentOpenCount
});




}
/// @nodoc
class __$ConversationPreferenceCopyWithImpl<$Res>
    implements _$ConversationPreferenceCopyWith<$Res> {
  __$ConversationPreferenceCopyWithImpl(this._self, this._then);

  final _ConversationPreference _self;
  final $Res Function(_ConversationPreference) _then;

/// Create a copy of ConversationPreference
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? squadId = null,Object? remark = null,Object? pinnedAt = freezed,Object? lastOpenedAt = freezed,Object? recentOpenCount = null,}) {
  return _then(_ConversationPreference(
squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,remark: null == remark ? _self.remark : remark // ignore: cast_nullable_to_non_nullable
as String,pinnedAt: freezed == pinnedAt ? _self.pinnedAt : pinnedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastOpenedAt: freezed == lastOpenedAt ? _self.lastOpenedAt : lastOpenedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,recentOpenCount: null == recentOpenCount ? _self.recentOpenCount : recentOpenCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
