// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'squad_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SquadDto {

 String get id; String get name; String? get description;@JsonKey(name: 'avatar_url') String? get avatarUrl;@JsonKey(name: 'invite_code') String get inviteCode;@JsonKey(name: 'max_members') int get maxMembers;@JsonKey(name: 'created_by') String get createdBy;@JsonKey(name: 'created_at') String get createdAt;
/// Create a copy of SquadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SquadDtoCopyWith<SquadDto> get copyWith => _$SquadDtoCopyWithImpl<SquadDto>(this as SquadDto, _$identity);

  /// Serializes this SquadDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SquadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&(identical(other.maxMembers, maxMembers) || other.maxMembers == maxMembers)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,avatarUrl,inviteCode,maxMembers,createdBy,createdAt);

@override
String toString() {
  return 'SquadDto(id: $id, name: $name, description: $description, avatarUrl: $avatarUrl, inviteCode: $inviteCode, maxMembers: $maxMembers, createdBy: $createdBy, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SquadDtoCopyWith<$Res>  {
  factory $SquadDtoCopyWith(SquadDto value, $Res Function(SquadDto) _then) = _$SquadDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description,@JsonKey(name: 'avatar_url') String? avatarUrl,@JsonKey(name: 'invite_code') String inviteCode,@JsonKey(name: 'max_members') int maxMembers,@JsonKey(name: 'created_by') String createdBy,@JsonKey(name: 'created_at') String createdAt
});




}
/// @nodoc
class _$SquadDtoCopyWithImpl<$Res>
    implements $SquadDtoCopyWith<$Res> {
  _$SquadDtoCopyWithImpl(this._self, this._then);

  final SquadDto _self;
  final $Res Function(SquadDto) _then;

/// Create a copy of SquadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? avatarUrl = freezed,Object? inviteCode = null,Object? maxMembers = null,Object? createdBy = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,maxMembers: null == maxMembers ? _self.maxMembers : maxMembers // ignore: cast_nullable_to_non_nullable
as int,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SquadDto].
extension SquadDtoPatterns on SquadDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SquadDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SquadDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SquadDto value)  $default,){
final _that = this;
switch (_that) {
case _SquadDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SquadDto value)?  $default,){
final _that = this;
switch (_that) {
case _SquadDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(name: 'invite_code')  String inviteCode, @JsonKey(name: 'max_members')  int maxMembers, @JsonKey(name: 'created_by')  String createdBy, @JsonKey(name: 'created_at')  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SquadDto() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.avatarUrl,_that.inviteCode,_that.maxMembers,_that.createdBy,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(name: 'invite_code')  String inviteCode, @JsonKey(name: 'max_members')  int maxMembers, @JsonKey(name: 'created_by')  String createdBy, @JsonKey(name: 'created_at')  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _SquadDto():
return $default(_that.id,_that.name,_that.description,_that.avatarUrl,_that.inviteCode,_that.maxMembers,_that.createdBy,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(name: 'invite_code')  String inviteCode, @JsonKey(name: 'max_members')  int maxMembers, @JsonKey(name: 'created_by')  String createdBy, @JsonKey(name: 'created_at')  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SquadDto() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.avatarUrl,_that.inviteCode,_that.maxMembers,_that.createdBy,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SquadDto implements SquadDto {
  const _SquadDto({required this.id, required this.name, this.description, @JsonKey(name: 'avatar_url') this.avatarUrl, @JsonKey(name: 'invite_code') required this.inviteCode, @JsonKey(name: 'max_members') this.maxMembers = 9, @JsonKey(name: 'created_by') required this.createdBy, @JsonKey(name: 'created_at') required this.createdAt});
  factory _SquadDto.fromJson(Map<String, dynamic> json) => _$SquadDtoFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
@override@JsonKey(name: 'avatar_url') final  String? avatarUrl;
@override@JsonKey(name: 'invite_code') final  String inviteCode;
@override@JsonKey(name: 'max_members') final  int maxMembers;
@override@JsonKey(name: 'created_by') final  String createdBy;
@override@JsonKey(name: 'created_at') final  String createdAt;

/// Create a copy of SquadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SquadDtoCopyWith<_SquadDto> get copyWith => __$SquadDtoCopyWithImpl<_SquadDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SquadDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SquadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&(identical(other.maxMembers, maxMembers) || other.maxMembers == maxMembers)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,avatarUrl,inviteCode,maxMembers,createdBy,createdAt);

@override
String toString() {
  return 'SquadDto(id: $id, name: $name, description: $description, avatarUrl: $avatarUrl, inviteCode: $inviteCode, maxMembers: $maxMembers, createdBy: $createdBy, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SquadDtoCopyWith<$Res> implements $SquadDtoCopyWith<$Res> {
  factory _$SquadDtoCopyWith(_SquadDto value, $Res Function(_SquadDto) _then) = __$SquadDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description,@JsonKey(name: 'avatar_url') String? avatarUrl,@JsonKey(name: 'invite_code') String inviteCode,@JsonKey(name: 'max_members') int maxMembers,@JsonKey(name: 'created_by') String createdBy,@JsonKey(name: 'created_at') String createdAt
});




}
/// @nodoc
class __$SquadDtoCopyWithImpl<$Res>
    implements _$SquadDtoCopyWith<$Res> {
  __$SquadDtoCopyWithImpl(this._self, this._then);

  final _SquadDto _self;
  final $Res Function(_SquadDto) _then;

/// Create a copy of SquadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? avatarUrl = freezed,Object? inviteCode = null,Object? maxMembers = null,Object? createdBy = null,Object? createdAt = null,}) {
  return _then(_SquadDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,maxMembers: null == maxMembers ? _self.maxMembers : maxMembers // ignore: cast_nullable_to_non_nullable
as int,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
