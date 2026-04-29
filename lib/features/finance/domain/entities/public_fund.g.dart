// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_fund.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicFund _$PublicFundFromJson(Map<String, dynamic> json) => _PublicFund(
  id: json['id'] as String,
  squadId: json['squadId'] as String,
  name: json['name'] as String,
  fundType: json['fundType'] as String,
  targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
  currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0,
  createdBy: json['createdBy'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$PublicFundToJson(_PublicFund instance) =>
    <String, dynamic>{
      'id': instance.id,
      'squadId': instance.squadId,
      'name': instance.name,
      'fundType': instance.fundType,
      'targetAmount': instance.targetAmount,
      'currentAmount': instance.currentAmount,
      'createdBy': instance.createdBy,
      'createdAt': instance.createdAt.toIso8601String(),
    };
