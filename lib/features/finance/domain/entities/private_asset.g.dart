// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'private_asset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PrivateAsset _$PrivateAssetFromJson(Map<String, dynamic> json) =>
    _PrivateAsset(
      id: json['id'] as String,
      userId: json['userId'] as String,
      assetType: json['assetType'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$PrivateAssetToJson(_PrivateAsset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'assetType': instance.assetType,
      'name': instance.name,
      'amount': instance.amount,
      'note': instance.note,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
