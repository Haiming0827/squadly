// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'squad_member.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SquadMember {

 String get id; String get squadId; String get userId; String get role;// 'captain' | 'member'
 DateTime get joinedAt;// 关联用户信息（查询时 join）
 String? get nickname; String? get avatarUrl;
/// Create a copy of SquadMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SquadMemberCopyWith<SquadMember> get copyWith => _$SquadMemberCopyWithImpl<SquadMember>(this as SquadMember, _$identity);

  /// Serializes this SquadMember to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SquadMember&&(identical(other.id, id) || other.id == id)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,squadId,userId,role,joinedAt,nickname,avatarUrl);

@override
String toString() {
  return 'SquadMember(id: $id, squadId: $squadId, userId: $userId, role: $role, joinedAt: $joinedAt, nickname: $nickname, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $SquadMemberCopyWith<$Res>  {
  factory $SquadMemberCopyWith(SquadMember value, $Res Function(SquadMember) _then) = _$SquadMemberCopyWithImpl;
@useResult
$Res call({
 String id, String squadId, String userId, String role, DateTime joinedAt, String? nickname, String? avatarUrl
});




}
/// @nodoc
class _$SquadMemberCopyWithImpl<$Res>
    implements $SquadMemberCopyWith<$Res> {
  _$SquadMemberCopyWithImpl(this._self, this._then);

  final SquadMember _self;
  final $Res Function(SquadMember) _then;

/// Create a copy of SquadMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? squadId = null,Object? userId = null,Object? role = null,Object? joinedAt = null,Object? nickname = freezed,Object? avatarUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SquadMember].
extension SquadMemberPatterns on SquadMember {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SquadMember value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SquadMember() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SquadMember value)  $default,){
final _that = this;
switch (_that) {
case _SquadMember():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SquadMember value)?  $default,){
final _that = this;
switch (_that) {
case _SquadMember() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String squadId,  String userId,  String role,  DateTime joinedAt,  String? nickname,  String? avatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SquadMember() when $default != null:
return $default(_that.id,_that.squadId,_that.userId,_that.role,_that.joinedAt,_that.nickname,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String squadId,  String userId,  String role,  DateTime joinedAt,  String? nickname,  String? avatarUrl)  $default,) {final _that = this;
switch (_that) {
case _SquadMember():
return $default(_that.id,_that.squadId,_that.userId,_that.role,_that.joinedAt,_that.nickname,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String squadId,  String userId,  String role,  DateTime joinedAt,  String? nickname,  String? avatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _SquadMember() when $default != null:
return $default(_that.id,_that.squadId,_that.userId,_that.role,_that.joinedAt,_that.nickname,_that.avatarUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SquadMember implements SquadMember {
  const _SquadMember({required this.id, required this.squadId, required this.userId, required this.role, required this.joinedAt, this.nickname, this.avatarUrl});
  factory _SquadMember.fromJson(Map<String, dynamic> json) => _$SquadMemberFromJson(json);

@override final  String id;
@override final  String squadId;
@override final  String userId;
@override final  String role;
// 'captain' | 'member'
@override final  DateTime joinedAt;
// 关联用户信息（查询时 join）
@override final  String? nickname;
@override final  String? avatarUrl;

/// Create a copy of SquadMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SquadMemberCopyWith<_SquadMember> get copyWith => __$SquadMemberCopyWithImpl<_SquadMember>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SquadMemberToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SquadMember&&(identical(other.id, id) || other.id == id)&&(identical(other.squadId, squadId) || other.squadId == squadId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,squadId,userId,role,joinedAt,nickname,avatarUrl);

@override
String toString() {
  return 'SquadMember(id: $id, squadId: $squadId, userId: $userId, role: $role, joinedAt: $joinedAt, nickname: $nickname, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class _$SquadMemberCopyWith<$Res> implements $SquadMemberCopyWith<$Res> {
  factory _$SquadMemberCopyWith(_SquadMember value, $Res Function(_SquadMember) _then) = __$SquadMemberCopyWithImpl;
@override @useResult
$Res call({
 String id, String squadId, String userId, String role, DateTime joinedAt, String? nickname, String? avatarUrl
});




}
/// @nodoc
class __$SquadMemberCopyWithImpl<$Res>
    implements _$SquadMemberCopyWith<$Res> {
  __$SquadMemberCopyWithImpl(this._self, this._then);

  final _SquadMember _self;
  final $Res Function(_SquadMember) _then;

/// Create a copy of SquadMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? squadId = null,Object? userId = null,Object? role = null,Object? joinedAt = null,Object? nickname = freezed,Object? avatarUrl = freezed,}) {
  return _then(_SquadMember(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,squadId: null == squadId ? _self.squadId : squadId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
