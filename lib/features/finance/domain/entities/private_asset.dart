import 'package:freezed_annotation/freezed_annotation.dart';

part 'private_asset.freezed.dart';
part 'private_asset.g.dart';

/// 个人私密资产实体（仅本人可见）
@freezed
abstract class PrivateAsset with _$PrivateAsset {
  const factory PrivateAsset({
    required String id,
    required String userId,
    required String assetType, // 'savings' | 'stock' | 'fund' | 'other'
    required String name,
    @Default(0) double amount,
    String? note,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _PrivateAsset;

  factory PrivateAsset.fromJson(Map<String, dynamic> json) =>
      _$PrivateAssetFromJson(json);
}
