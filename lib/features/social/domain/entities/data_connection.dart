const _unset = Object();

/// 第三方数据源在当前用户个人空间中的连接状态。
final class DataConnection {
  DataConnection({
    required this.id,
    required this.userId,
    required this.provider,
    required this.displayName,
    required this.mode,
    required this.isConnected,
    List<String> enabledTypes = const [],
    this.lastSyncedAt,
  }) : enabledTypes = List.unmodifiable(enabledTypes);

  final String id;
  final String userId;
  final String provider;
  final String displayName;
  final String mode;
  final bool isConnected;
  final List<String> enabledTypes;
  final DateTime? lastSyncedAt;

  DataConnection copyWith({
    String? id,
    String? userId,
    String? provider,
    String? displayName,
    String? mode,
    bool? isConnected,
    List<String>? enabledTypes,
    Object? lastSyncedAt = _unset,
  }) => DataConnection(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    provider: provider ?? this.provider,
    displayName: displayName ?? this.displayName,
    mode: mode ?? this.mode,
    isConnected: isConnected ?? this.isConnected,
    enabledTypes: enabledTypes ?? this.enabledTypes,
    lastSyncedAt: identical(lastSyncedAt, _unset)
        ? this.lastSyncedAt
        : lastSyncedAt as DateTime?,
  );

  factory DataConnection.fromJson(Map<String, dynamic> json) => DataConnection(
    id: json['id'] as String,
    userId: json['userId'] as String,
    provider: json['provider'] as String,
    displayName: json['displayName'] as String,
    mode: json['mode'] as String,
    isConnected: json['isConnected'] as bool,
    enabledTypes:
        (json['enabledTypes'] as List<dynamic>?)
            ?.map((value) => value as String)
            .toList() ??
        const [],
    lastSyncedAt: json['lastSyncedAt'] == null
        ? null
        : DateTime.parse(json['lastSyncedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'provider': provider,
    'displayName': displayName,
    'mode': mode,
    'isConnected': isConnected,
    'enabledTypes': enabledTypes,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };
}
