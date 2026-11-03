import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/error/failures.dart';
import '../../features/conversation/domain/conversation_preference.dart';
import '../../features/squad/domain/repositories/squad_profile_repository.dart';
import '../../features/squad/domain/squad_avatar_format.dart';
import 'demo_store.dart';

final class DemoConversationCustomization
    implements ConversationCustomizationRepository {
  DemoConversationCustomization(this.store, this.userId);
  final DemoAppStore store;
  final String userId;
  String? _key(String squadId) {
    if (store.getCurrentUser()?.id != userId) return null;
    for (final m in store.snapshot.members) {
      if (m.squadId == squadId && m.userId == userId) {
        return 'conversation-pref-$userId-${m.id}';
      }
    }
    return null;
  }

  @override
  Future<Either<Failure, List<ConversationPreference>>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = <ConversationPreference>[];
      for (final squad in store.snapshot.mySquads) {
        final key = _key(squad.id);
        if (key == null) continue;
        final data =
            jsonDecode(prefs.getString(key) ?? '{}') as Map<String, dynamic>;
        final days = Map<String, dynamic>.from(data['days'] as Map? ?? {});
        final cutoff = _today().subtract(const Duration(days: 6));
        final total = days.entries
            .where((e) {
              final date = DateTime.tryParse(e.key);
              return date != null &&
                  !date.isBefore(cutoff) &&
                  !date.isAfter(_today());
            })
            .fold<int>(0, (sum, e) => sum + (e.value as num).toInt());
        result.add(
          ConversationPreference(
            squadId: squad.id,
            remark: data['remark'] as String? ?? '',
            pinnedAt: DateTime.tryParse(data['pinned_at'] as String? ?? ''),
            lastOpenedAt: DateTime.tryParse(
              data['last_opened_at'] as String? ?? '',
            ),
            recentOpenCount: total,
          ),
        );
      }
      return right(result);
    } catch (_) {
      return left(const Failure.server(message: '本机会话设置加载失败'));
    }
  }

  DateTime _today() {
    final cn = DateTime.now().toUtc().add(const Duration(hours: 8));
    return DateTime.utc(cn.year, cn.month, cn.day);
  }

  Future<void> _pending = Future.value();

  Future<Either<Failure, void>> _change(
    String squadId,
    void Function(Map<String, dynamic>) change,
  ) {
    final operation = _pending.then((_) => _writeChange(squadId, change));
    _pending = operation.then((_) {});
    return operation;
  }

  Future<Either<Failure, void>> _writeChange(
    String squadId,
    void Function(Map<String, dynamic>) change,
  ) async {
    try {
      final key = _key(squadId);
      if (key == null) return left(const Failure.permissionDenied());
      final prefs = await SharedPreferences.getInstance();
      if (_key(squadId) != key) return left(const Failure.unauthorized());
      final data =
          jsonDecode(prefs.getString(key) ?? '{}') as Map<String, dynamic>;
      change(data);
      final saved = await prefs.setString(key, jsonEncode(data));
      return saved
          ? right(null)
          : left(const Failure.server(message: '本机会话设置未保存'));
    } catch (_) {
      return left(const Failure.server(message: '本机会话设置未保存'));
    }
  }

  @override
  Future<Either<Failure, void>> save({
    required String squadId,
    required String remark,
    required bool pinned,
  }) {
    if (remark.trim().runes.length > 40) {
      return Future.value(
        left(const Failure.validation(message: '备注最多 40 个字')),
      );
    }
    return _change(squadId, (data) {
      data['remark'] = remark.trim();
      data['pinned_at'] = pinned
          ? data['pinned_at'] ?? DateTime.now().toUtc().toIso8601String()
          : null;
    });
  }

  @override
  Future<Either<Failure, void>> recordOpen(String squadId) =>
      _change(squadId, (data) {
        final days = Map<String, dynamic>.from(data['days'] as Map? ?? {});
        final today = _today().toIso8601String().substring(0, 10);
        days.removeWhere(
          (key, _) =>
              DateTime.parse(key)
                  .isBefore(_today().subtract(const Duration(days: 6))),
        );
        days[today] = ((days[today] as num?)?.toInt() ?? 0) + 1;
        if ((days[today] as int) > 100) days[today] = 100;
        data['days'] = days;
        data['last_opened_at'] = DateTime.now().toUtc().toIso8601String();
      });
}

final class DemoSquadProfileRepository implements SquadProfileRepository {
  const DemoSquadProfileRepository(this.store);
  final DemoAppStore store;
  @override
  Future<Either<Failure, void>> save({
    required String squadId,
    required String name,
    required String description,
    required String? avatar,
  }) async {
    if (name.trim().isEmpty ||
        name.trim().runes.length > 40 ||
        description.runes.length > 200 ||
        (avatar != null && decodeSquadAvatar(avatar) == null)) {
      return left(const Failure.validation(message: '请检查名称、简介和头像'));
    }
    try {
      store.updateSquadProfile(
        squadId,
        name: name.trim(),
        description: description.trim(),
        avatar: avatar,
      );
      return right(null);
    } on StateError {
      return left(const Failure.permissionDenied());
    }
  }
}
