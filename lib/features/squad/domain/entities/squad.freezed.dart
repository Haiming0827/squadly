// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'squad.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Squad {

 String get id; String get name; String? get description; String? get avatarUrl; String get inviteCode; int get maxMembers; String get createdBy; DateTime get createdAt;
/// Create a copy of Squad
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SquadCopyWith<Squad> get copyWith => _$SquadCopyWithImpl<Squad>(this as Squad, _$identity);

  /// Serializes this Squad to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Squad&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&(identical(other.maxMembers, maxMembers) || other.maxMembers == maxMembers)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,avatarUrl,inviteCode,maxMembers,createdBy,createdAt);

@override
String toString() {
  return 'Squad(id: $id, name: $name, description: $description, avatarUrl: $avatarUrl, inviteCode: $inviteCode, maxMembers: $maxMembers, createdBy: $createdBy, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SquadCopyWith<$Res>  {
  factory $SquadCopyWith(Squad value, $Res Function(Squad) _then) = _$SquadCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, String? avatarUrl, String inviteCode, int maxMembers, String createdBy, DateTime createdAt
});




}
/// @nodoc
class _$SquadCopyWithImpl<$Res>
    implements $SquadCopyWith<$Res> {
  _$SquadCopyWithImpl(this._self, this._then);

  final Squad _self;
  final $Res Function(Squad) _then;

/// Create a copy of Squad
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
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Squad].
extension SquadPatterns on Squad {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Squad value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Squad() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Squad value)  $default,){
final _that = this;
switch (_that) {
case _Squad():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Squad value)?  $default,){
final _that = this;
switch (_that) {
case _Squad() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  String? avatarUrl,  String inviteCode,  int maxMembers,  String createdBy,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Squad() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  String? avatarUrl,  String inviteCode,  int maxMembers,  String createdBy,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Squad():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description,  String? avatarUrl,  String inviteCode,  int maxMembers,  String createdBy,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Squad() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.avatarUrl,_that.inviteCode,_that.maxMembers,_that.createdBy,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Squad implements Squad {
  const _Squad({required this.id, required this.name, this.description, this.avatarUrl, required this.inviteCode, this.maxMembers = 9, required this.createdBy, required this.createdAt});
  factory _Squad.fromJson(Map<String, dynamic> json) => _$SquadFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
@override final  String? avatarUrl;
@override final  String inviteCode;
@override@JsonKey() final  int maxMembers;
@override final  String createdBy;
@override final  DateTime createdAt;

/// Create a copy of Squad
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SquadCopyWith<_Squad> get copyWith => __$SquadCopyWithImpl<_Squad>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SquadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Squad&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&(identical(other.maxMembers, maxMembers) || other.maxMembers == maxMembers)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,avatarUrl,inviteCode,maxMembers,createdBy,createdAt);

@override
String toString() {
  return 'Squad(id: $id, name: $name, description: $description, avatarUrl: $avatarUrl, inviteCode: $inviteCode, maxMembers: $maxMembers, createdBy: $createdBy, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SquadCopyWith<$Res> implements $SquadCopyWith<$Res> {
  factory _$SquadCopyWith(_Squad value, $Res Function(_Squad) _then) = __$SquadCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, String? avatarUrl, String inviteCode, int maxMembers, String createdBy, DateTime createdAt
});




}
/// @nodoc
class __$SquadCopyWithImpl<$Res>
    implements _$SquadCopyWith<$Res> {
  __$SquadCopyWithImpl(this._self, this._then);

  final _Squad _self;
  final $Res Function(_Squad) _then;

/// Create a copy of Squad
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? avatarUrl = freezed,Object? inviteCode = null,Object? maxMembers = null,Object? createdBy = null,Object? createdAt = null,}) {
  return _then(_Squad(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,maxMembers: null == maxMembers ? _self.maxMembers : maxMembers // ignore: cast_nullable_to_non_nullable
as int,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
