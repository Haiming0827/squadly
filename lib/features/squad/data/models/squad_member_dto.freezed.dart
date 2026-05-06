// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'squad_member_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SquadMemberDto {

 String get id;@JsonKey(name: 'squad_id') String get squadId;@JsonKey(name: 'user_id') String get userId; String get role;@JsonKey(name: 'joined_at') String get joinedAt;// join profiles 时的嵌套数据
 Map<String, dynamic>? get profiles;
/// Create a copy of SquadMemberDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SquadMemberDtoCopyWith<SquadMemberDto> get copyWith => _$SquadMemberDtoCopyWithImpl<SquadMemberDto>(this as SquadMemberDto, _$identity);

  /// Serializes this SquadMemberDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SquadMemberDto&&(identical(other.id, id) || other.id == id)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&const DeepCollectionEquality().equals(other.profiles, profiles));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,squadId,userId,role,joinedAt,const DeepCollectionEquality().hash(profiles));

@override
String toString() {
  return 'SquadMemberDto(id: $id, squadId: $squadId, userId: $userId, role: $role, joinedAt: $joinedAt, profiles: $profiles)';
}


}

/// @nodoc
abstract mixin class $SquadMemberDtoCopyWith<$Res>  {
  factory $SquadMemberDtoCopyWith(SquadMemberDto value, $Res Function(SquadMemberDto) _then) = _$SquadMemberDtoCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'squad_id') String squadId,@JsonKey(name: 'user_id') String userId, String role,@JsonKey(name: 'joined_at') String joinedAt, Map<String, dynamic>? profiles
});




}
/// @nodoc
class _$SquadMemberDtoCopyWithImpl<$Res>
    implements $SquadMemberDtoCopyWith<$Res> {
  _$SquadMemberDtoCopyWithImpl(this._self, this._then);

  final SquadMemberDto _self;
  final $Res Function(SquadMemberDto) _then;

/// Create a copy of SquadMemberDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? squadId = null,Object? userId = null,Object? role = null,Object? joinedAt = null,Object? profiles = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as String,profiles: freezed == profiles ? _self.profiles : profiles // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [SquadMemberDto].
extension SquadMemberDtoPatterns on SquadMemberDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SquadMemberDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SquadMemberDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SquadMemberDto value)  $default,){
final _that = this;
switch (_that) {
case _SquadMemberDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SquadMemberDto value)?  $default,){
final _that = this;
switch (_that) {
case _SquadMemberDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'squad_id')  String squadId, @JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'joined_at')  String joinedAt,  Map<String, dynamic>? profiles)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SquadMemberDto() when $default != null:
return $default(_that.id,_that.squadId,_that.userId,_that.role,_that.joinedAt,_that.profiles);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'squad_id')  String squadId, @JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'joined_at')  String joinedAt,  Map<String, dynamic>? profiles)  $default,) {final _that = this;
switch (_that) {
case _SquadMemberDto():
return $default(_that.id,_that.squadId,_that.userId,_that.role,_that.joinedAt,_that.profiles);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'squad_id')  String squadId, @JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'joined_at')  String joinedAt,  Map<String, dynamic>? profiles)?  $default,) {final _that = this;
switch (_that) {
case _SquadMemberDto() when $default != null:
return $default(_that.id,_that.squadId,_that.userId,_that.role,_that.joinedAt,_that.profiles);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SquadMemberDto implements SquadMemberDto {
  const _SquadMemberDto({required this.id, @JsonKey(name: 'squad_id') required this.squadId, @JsonKey(name: 'user_id') required this.userId, required this.role, @JsonKey(name: 'joined_at') required this.joinedAt, final  Map<String, dynamic>? profiles}): _profiles = profiles;
  factory _SquadMemberDto.fromJson(Map<String, dynamic> json) => _$SquadMemberDtoFromJson(json);

@override final  String id;
@override@JsonKey(name: 'squad_id') final  String squadId;
@override@JsonKey(name: 'user_id') final  String userId;
@override final  String role;
@override@JsonKey(name: 'joined_at') final  String joinedAt;
// join profiles 时的嵌套数据
 final  Map<String, dynamic>? _profiles;
// join profiles 时的嵌套数据
@override Map<String, dynamic>? get profiles {
  final value = _profiles;
  if (value == null) return null;
  if (_profiles is EqualUnmodifiableMapView) return _profiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of SquadMemberDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SquadMemberDtoCopyWith<_SquadMemberDto> get copyWith => __$SquadMemberDtoCopyWithImpl<_SquadMemberDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SquadMemberDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SquadMemberDto&&(identical(other.id, id) || other.id == id)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&const DeepCollectionEquality().equals(other._profiles, _profiles));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,squadId,userId,role,joinedAt,const DeepCollectionEquality().hash(_profiles));

@override
String toString() {
  return 'SquadMemberDto(id: $id, squadId: $squadId, userId: $userId, role: $role, joinedAt: $joinedAt, profiles: $profiles)';
}


}

/// @nodoc
abstract mixin class _$SquadMemberDtoCopyWith<$Res> implements $SquadMemberDtoCopyWith<$Res> {
  factory _$SquadMemberDtoCopyWith(_SquadMemberDto value, $Res Function(_SquadMemberDto) _then) = __$SquadMemberDtoCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'squad_id') String squadId,@JsonKey(name: 'user_id') String userId, String role,@JsonKey(name: 'joined_at') String joinedAt, Map<String, dynamic>? profiles
});




}
/// @nodoc
class __$SquadMemberDtoCopyWithImpl<$Res>
    implements _$SquadMemberDtoCopyWith<$Res> {
  __$SquadMemberDtoCopyWithImpl(this._self, this._then);

  final _SquadMemberDto _self;
  final $Res Function(_SquadMemberDto) _then;

/// Create a copy of SquadMemberDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? squadId = null,Object? userId = null,Object? role = null,Object? joinedAt = null,Object? profiles = freezed,}) {
  return _then(_SquadMemberDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as String,profiles: freezed == profiles ? _self._profiles : profiles // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}

// dart format on
