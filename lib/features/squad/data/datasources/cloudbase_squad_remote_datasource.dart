import 'package:postgrest/postgrest.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/issued_invitation.dart';
import '../../domain/invitation_credential.dart';
import '../models/squad_dto.dart';
import '../models/squad_member_dto.dart';

/// 小队远程数据源
class CloudBaseSquadRemoteDatasource {
  final PostgrestClient _client;

  CloudBaseSquadRemoteDatasource(this._client);

  SquadDto _squadFromRpc(Object? response) {
    if (response is! Map) {
      throw const ServerException(message: '小队服务返回格式无效');
    }
    final data = Map<String, dynamic>.from(response);
    final error = data['error'];
    if (error != null) {
      throw ServerException(message: _invitationError(error.toString()));
    }
    // The legacy DTO still has inviteCode for the demo adapter. Real invite
    // credentials are issued separately and are never persisted on squads.
    data['invite_code'] = '';
    return SquadDto.fromJson(data);
  }

  String _invitationError(String code) => switch (code) {
    'unauthenticated' => '请先登录',
    'invalid_squad' => '小队名称或描述无效',
    'invalid_uses' => '邀请使用次数无效',
    'not_captain' => '只有队长可以邀请成员',
    'not_found' => '小队不存在',
    'squad_full' => '小队已满员',
    'invalid_invitation' => '邀请码或邀请链接无效或已过期',
    'already_member' => '你已经是该小队成员',
    'rate_limited' => '尝试次数过多，请稍后再试',
    _ => '邀请码或邀请链接无效',
  };

  /// 创建小队
  Future<SquadDto> createSquad({
    required String name,
    String? description,
  }) async {
    try {
      return _squadFromRpc(
        await _client.rpc(
          'create_squad',
          params: {'p_name': name, 'p_description': description},
        ),
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 获取我的小队列表
  Future<List<SquadDto>> getMySquads() async {
    try {
      // RLS limits this query to squads for the authenticated identity.
      final memberRows = await _client.from('squad_members').select('squad_id');

      final squadIds = (memberRows as List)
          .map((r) => r['squad_id'] as String)
          .toList();

      if (squadIds.isEmpty) return [];

      final data = await _client
          .from('squads')
          .select(
            'id,name,description,avatar_url,max_members,created_by,created_at',
          )
          .inFilter('id', squadIds)
          .order('created_at', ascending: false);

      return (data as List).map((e) => _squadFromRpc(e)).toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  Future<IssuedInvitation> issueInvitation({required String squadId}) async {
    try {
      final response = await _client.rpc(
        'issue_invitation',
        params: {'p_squad_id': squadId},
      );
      if (response is! Map) {
        throw const ServerException(message: '邀请服务返回格式无效');
      }
      final data = Map<String, dynamic>.from(response);
      final error = data['error'];
      if (error != null) {
        throw ServerException(message: _invitationError(error.toString()));
      }
      return IssuedInvitation(
        id: data['invitation_id'] as String,
        code: data['code'] as String,
        linkToken: data['link_token'] as String,
        expiresAt: DateTime.parse(data['expires_at'] as String),
        maxUses: data['max_uses'] as int,
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  Future<SquadDto> redeemInvitation({required String credential}) async {
    try {
      return _squadFromRpc(
        await _client.rpc(
          'redeem_invitation',
          params: {'p_credential': InvitationCredential.parse(credential)},
        ),
      );
    } on FormatException catch (e) {
      throw ServerException(message: e.message);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  Future<SquadDto> joinSquad({required String inviteCode}) =>
      redeemInvitation(credential: inviteCode);

  /// 获取小队成员列表
  Future<List<SquadMemberDto>> getSquadMembers({
    required String squadId,
  }) async {
    try {
      final data = await _client
          .from('squad_members')
          .select(
            'id,squad_id,user_id,role,joined_at,profiles(nickname,avatar_url)',
          )
          .eq('squad_id', squadId)
          .order('joined_at');

      return (data as List).map((e) => SquadMemberDto.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 移除成员（仅队长）
  Future<void> removeMember({
    required String squadId,
    required String userId,
  }) async {
    try {
      await _client.rpc(
        'remove_squad_member',
        params: {'p_squad_id': squadId, 'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 退出小队
  Future<void> leaveSquad({required String squadId}) async {
    try {
      await _client.rpc('leave_squad', params: {'p_squad_id': squadId});
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 转让队长
  Future<void> transferCaptain({
    required String squadId,
    required String newCaptainId,
  }) async {
    try {
      await _client.rpc(
        'transfer_squad_captain',
        params: {'p_squad_id': squadId, 'p_new_captain_id': newCaptainId},
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }
}
