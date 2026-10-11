// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ActivityRecord {

 String get id; ActivitySourceKind get source; ActivityKind get kind; DateTime get startedAt; int get utcOffsetMinutes; double get distanceMeters; int get durationSeconds; String get sourceLabel; int? get averageHeartRateBpm; List<RouteCoordinate>? get preciseRoute; Set<String> get correctedFields;
/// Create a copy of ActivityRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivityRecordCopyWith<ActivityRecord> get copyWith => _$ActivityRecordCopyWithImpl<ActivityRecord>(this as ActivityRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivityRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.source, source) || other.source == source)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.utcOffsetMinutes, utcOffsetMinutes) || other.utcOffsetMinutes == utcOffsetMinutes)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.averageHeartRateBpm, averageHeartRateBpm) || other.averageHeartRateBpm == averageHeartRateBpm)&&const DeepCollectionEquality().equals(other.preciseRoute, preciseRoute)&&const DeepCollectionEquality().equals(other.correctedFields, correctedFields));
}


@override
int get hashCode => Object.hash(runtimeType,id,source,kind,startedAt,utcOffsetMinutes,distanceMeters,durationSeconds,sourceLabel,averageHeartRateBpm,const DeepCollectionEquality().hash(preciseRoute),const DeepCollectionEquality().hash(correctedFields));

@override
String toString() {
  return 'ActivityRecord(id: $id, source: $source, kind: $kind, startedAt: $startedAt, utcOffsetMinutes: $utcOffsetMinutes, distanceMeters: $distanceMeters, durationSeconds: $durationSeconds, sourceLabel: $sourceLabel, averageHeartRateBpm: $averageHeartRateBpm, preciseRoute: $preciseRoute, correctedFields: $correctedFields)';
}


}

/// @nodoc
abstract mixin class $ActivityRecordCopyWith<$Res>  {
  factory $ActivityRecordCopyWith(ActivityRecord value, $Res Function(ActivityRecord) _then) = _$ActivityRecordCopyWithImpl;
@useResult
$Res call({
 String id, ActivitySourceKind source, ActivityKind kind, DateTime startedAt, int utcOffsetMinutes, double distanceMeters, int durationSeconds, String sourceLabel, int? averageHeartRateBpm, List<RouteCoordinate>? preciseRoute, Set<String> correctedFields
});




}
/// @nodoc
class _$ActivityRecordCopyWithImpl<$Res>
    implements $ActivityRecordCopyWith<$Res> {
  _$ActivityRecordCopyWithImpl(this._self, this._then);

  final ActivityRecord _self;
  final $Res Function(ActivityRecord) _then;

/// Create a copy of ActivityRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? source = null,Object? kind = null,Object? startedAt = null,Object? utcOffsetMinutes = null,Object? distanceMeters = null,Object? durationSeconds = null,Object? sourceLabel = null,Object? averageHeartRateBpm = freezed,Object? preciseRoute = freezed,Object? correctedFields = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ActivitySourceKind,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ActivityKind,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffsetMinutes: null == utcOffsetMinutes ? _self.utcOffsetMinutes : utcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,distanceMeters: null == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as double,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,sourceLabel: null == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String,averageHeartRateBpm: freezed == averageHeartRateBpm ? _self.averageHeartRateBpm : averageHeartRateBpm // ignore: cast_nullable_to_non_nullable
as int?,preciseRoute: freezed == preciseRoute ? _self.preciseRoute : preciseRoute // ignore: cast_nullable_to_non_nullable
as List<RouteCoordinate>?,correctedFields: null == correctedFields ? _self.correctedFields : correctedFields // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivityRecord].
extension ActivityRecordPatterns on ActivityRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivityRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivityRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivityRecord value)  $default,){
final _that = this;
switch (_that) {
case _ActivityRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivityRecord value)?  $default,){
final _that = this;
switch (_that) {
case _ActivityRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  ActivitySourceKind source,  ActivityKind kind,  DateTime startedAt,  int utcOffsetMinutes,  double distanceMeters,  int durationSeconds,  String sourceLabel,  int? averageHeartRateBpm,  List<RouteCoordinate>? preciseRoute,  Set<String> correctedFields)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivityRecord() when $default != null:
return $default(_that.id,_that.source,_that.kind,_that.startedAt,_that.utcOffsetMinutes,_that.distanceMeters,_that.durationSeconds,_that.sourceLabel,_that.averageHeartRateBpm,_that.preciseRoute,_that.correctedFields);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  ActivitySourceKind source,  ActivityKind kind,  DateTime startedAt,  int utcOffsetMinutes,  double distanceMeters,  int durationSeconds,  String sourceLabel,  int? averageHeartRateBpm,  List<RouteCoordinate>? preciseRoute,  Set<String> correctedFields)  $default,) {final _that = this;
switch (_that) {
case _ActivityRecord():
return $default(_that.id,_that.source,_that.kind,_that.startedAt,_that.utcOffsetMinutes,_that.distanceMeters,_that.durationSeconds,_that.sourceLabel,_that.averageHeartRateBpm,_that.preciseRoute,_that.correctedFields);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  ActivitySourceKind source,  ActivityKind kind,  DateTime startedAt,  int utcOffsetMinutes,  double distanceMeters,  int durationSeconds,  String sourceLabel,  int? averageHeartRateBpm,  List<RouteCoordinate>? preciseRoute,  Set<String> correctedFields)?  $default,) {final _that = this;
switch (_that) {
case _ActivityRecord() when $default != null:
return $default(_that.id,_that.source,_that.kind,_that.startedAt,_that.utcOffsetMinutes,_that.distanceMeters,_that.durationSeconds,_that.sourceLabel,_that.averageHeartRateBpm,_that.preciseRoute,_that.correctedFields);case _:
  return null;

}
}

}

/// @nodoc


class _ActivityRecord implements ActivityRecord {
  const _ActivityRecord({required this.id, required this.source, required this.kind, required this.startedAt, required this.utcOffsetMinutes, required this.distanceMeters, required this.durationSeconds, required this.sourceLabel, this.averageHeartRateBpm, final  List<RouteCoordinate>? preciseRoute, final  Set<String> correctedFields = const <String>{}}): _preciseRoute = preciseRoute,_correctedFields = correctedFields;


@override final  String id;
@override final  ActivitySourceKind source;
@override final  ActivityKind kind;
@override final  DateTime startedAt;
@override final  int utcOffsetMinutes;
@override final  double distanceMeters;
@override final  int durationSeconds;
@override final  String sourceLabel;
@override final  int? averageHeartRateBpm;
 final  List<RouteCoordinate>? _preciseRoute;
@override List<RouteCoordinate>? get preciseRoute {
  final value = _preciseRoute;
  if (value == null) return null;
  if (_preciseRoute is EqualUnmodifiableListView) return _preciseRoute;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  Set<String> _correctedFields;
@override@JsonKey() Set<String> get correctedFields {
  if (_correctedFields is EqualUnmodifiableSetView) return _correctedFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_correctedFields);
}


/// Create a copy of ActivityRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivityRecordCopyWith<_ActivityRecord> get copyWith => __$ActivityRecordCopyWithImpl<_ActivityRecord>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivityRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.source, source) || other.source == source)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.utcOffsetMinutes, utcOffsetMinutes) || other.utcOffsetMinutes == utcOffsetMinutes)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.averageHeartRateBpm, averageHeartRateBpm) || other.averageHeartRateBpm == averageHeartRateBpm)&&const DeepCollectionEquality().equals(other._preciseRoute, _preciseRoute)&&const DeepCollectionEquality().equals(other._correctedFields, _correctedFields));
}


@override
int get hashCode => Object.hash(runtimeType,id,source,kind,startedAt,utcOffsetMinutes,distanceMeters,durationSeconds,sourceLabel,averageHeartRateBpm,const DeepCollectionEquality().hash(_preciseRoute),const DeepCollectionEquality().hash(_correctedFields));

@override
String toString() {
  return 'ActivityRecord(id: $id, source: $source, kind: $kind, startedAt: $startedAt, utcOffsetMinutes: $utcOffsetMinutes, distanceMeters: $distanceMeters, durationSeconds: $durationSeconds, sourceLabel: $sourceLabel, averageHeartRateBpm: $averageHeartRateBpm, preciseRoute: $preciseRoute, correctedFields: $correctedFields)';
}


}

/// @nodoc
abstract mixin class _$ActivityRecordCopyWith<$Res> implements $ActivityRecordCopyWith<$Res> {
  factory _$ActivityRecordCopyWith(_ActivityRecord value, $Res Function(_ActivityRecord) _then) = __$ActivityRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, ActivitySourceKind source, ActivityKind kind, DateTime startedAt, int utcOffsetMinutes, double distanceMeters, int durationSeconds, String sourceLabel, int? averageHeartRateBpm, List<RouteCoordinate>? preciseRoute, Set<String> correctedFields
});




}
/// @nodoc
class __$ActivityRecordCopyWithImpl<$Res>
    implements _$ActivityRecordCopyWith<$Res> {
  __$ActivityRecordCopyWithImpl(this._self, this._then);

  final _ActivityRecord _self;
  final $Res Function(_ActivityRecord) _then;

/// Create a copy of ActivityRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? source = null,Object? kind = null,Object? startedAt = null,Object? utcOffsetMinutes = null,Object? distanceMeters = null,Object? durationSeconds = null,Object? sourceLabel = null,Object? averageHeartRateBpm = freezed,Object? preciseRoute = freezed,Object? correctedFields = null,}) {
  return _then(_ActivityRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ActivitySourceKind,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ActivityKind,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffsetMinutes: null == utcOffsetMinutes ? _self.utcOffsetMinutes : utcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,distanceMeters: null == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as double,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,sourceLabel: null == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String,averageHeartRateBpm: freezed == averageHeartRateBpm ? _self.averageHeartRateBpm : averageHeartRateBpm // ignore: cast_nullable_to_non_nullable
as int?,preciseRoute: freezed == preciseRoute ? _self._preciseRoute : preciseRoute // ignore: cast_nullable_to_non_nullable
as List<RouteCoordinate>?,correctedFields: null == correctedFields ? _self._correctedFields : correctedFields // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

// dart format on
