import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/squad_dto.dart';
import '../models/squad_member_dto.dart';

/// 小队远程数据源
class SquadRemoteDatasource {
  final SupabaseClient _client;

  SquadRemoteDatasource(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// 创建小队
  Future<SquadDto> createSquad({
    required String name,
    String? description,
  }) async {
    try {
      // 生成邀请码
      final codeResult = await _client.rpc('generate_invite_code');
      final inviteCode = codeResult as String;

      // 插入小队
      final data = await _client
          .from(SupabaseConstants.squads)
          .insert({
            'name': name,
            'description': description,
            'invite_code': inviteCode,
            'created_by': _userId,
          })
          .select()
          .single();

      // 创建者自动成为队长
      await _client.from(SupabaseConstants.squadMembers).insert({
        'squad_id': data['id'],
        'user_id': _userId,
        'role': AppConstants.roleCaptain,
      });

      return SquadDto.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 获取我的小队列表
  Future<List<SquadDto>> getMySquads() async {
    try {
      // 先获取我参与的 squad_id
      final memberRows = await _client
          .from(SupabaseConstants.squadMembers)
          .select('squad_id')
          .eq('user_id', _userId);

      final squadIds = (memberRows as List)
          .map((r) => r['squad_id'] as String)
          .toList();

      if (squadIds.isEmpty) return [];

      final data = await _client
          .from(SupabaseConstants.squads)
          .select()
          .inFilter('id', squadIds)
          .order('created_at', ascending: false);

      return (data as List).map((e) => SquadDto.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 通过邀请码加入小队
  Future<SquadDto> joinSquad({required String inviteCode}) async {
    try {
      // 查找小队
      final squadData = await _client
          .from(SupabaseConstants.squads)
          .select()
          .eq('invite_code', inviteCode.toUpperCase())
          .maybeSingle();

      if (squadData == null) {
        throw const ServerException(message: '邀请码无效');
      }

      final squad = SquadDto.fromJson(squadData);

      // 检查是否已经是成员
      final existing = await _client
          .from(SupabaseConstants.squadMembers)
          .select()
          .eq('squad_id', squad.id)
          .eq('user_id', _userId)
          .maybeSingle();

      if (existing != null) {
        throw const ServerException(message: '你已经是该小队成员');
      }

      // 检查人数上限
      final count =
          await _client.rpc(
                'get_squad_member_count',
                params: {'p_squad_id': squad.id},
              )
              as int;

      if (count >= squad.maxMembers) {
        throw const ServerException(message: '小队已满员');
      }

      // 加入小队
      await _client.from(SupabaseConstants.squadMembers).insert({
        'squad_id': squad.id,
        'user_id': _userId,
        'role': AppConstants.roleMember,
      });

      return squad;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 获取小队成员列表
  Future<List<SquadMemberDto>> getSquadMembers({
    required String squadId,
  }) async {
    try {
      final data = await _client
          .from(SupabaseConstants.squadMembers)
          .select('*, profiles(*)')
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
      // 不能移除自己
      if (userId == _userId) {
        throw const ServerException(message: '不能移除自己，请使用退出小队');
      }

      // 检查当前成员数（最少 2 人）
      final count =
          await _client.rpc(
                'get_squad_member_count',
                params: {'p_squad_id': squadId},
              )
              as int;

      if (count <= AppConstants.squadMinMembers) {
        throw const ServerException(message: '小队至少需要 2 人');
      }

      await _client
          .from(SupabaseConstants.squadMembers)
          .delete()
          .eq('squad_id', squadId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  /// 退出小队
  Future<void> leaveSquad({required String squadId}) async {
    try {
      // 检查是否是队长
      final myMembership = await _client
          .from(SupabaseConstants.squadMembers)
          .select()
          .eq('squad_id', squadId)
          .eq('user_id', _userId)
          .single();

      if (myMembership['role'] == AppConstants.roleCaptain) {
        throw const ServerException(message: '队长不能直接退出，请先转让队长');
      }

      // 检查人数
      final count =
          await _client.rpc(
                'get_squad_member_count',
                params: {'p_squad_id': squadId},
              )
              as int;

      if (count <= AppConstants.squadMinMembers) {
        throw const ServerException(message: '小队至少需要 2 人');
      }

      await _client
          .from(SupabaseConstants.squadMembers)
          .delete()
          .eq('squad_id', squadId)
          .eq('user_id', _userId);
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
      // 将原队长改为成员
      await _client
          .from(SupabaseConstants.squadMembers)
          .update({'role': AppConstants.roleMember})
          .eq('squad_id', squadId)
          .eq('user_id', _userId);

      // 将新队长改为队长
      await _client
          .from(SupabaseConstants.squadMembers)
          .update({'role': AppConstants.roleCaptain})
          .eq('squad_id', squadId)
          .eq('user_id', newCaptainId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }
}
