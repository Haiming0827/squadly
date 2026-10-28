import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers/activity_source_providers.dart';
import '../../../app/providers/conversation_runtime_providers.dart';
import '../../../app/providers/current_user_provider.dart';
import '../../../app/providers/route_providers.dart';
import '../../../app/providers/squad_context_providers.dart';
import '../../activity_import/domain/activity_record.dart';
import '../../activity_import/domain/activity_source.dart';
import '../../conversation/domain/conversation_target.dart';
import '../../conversation/domain/timeline_entry.dart';
import '../../secure_route/domain/route_fingerprint.dart';
import '../../secure_route/domain/route_models.dart';
import '../../secure_route/domain/route_sharing.dart';
import '../domain/card_composer.dart';
import 'card_preview.dart';

/// Creates an explicitly confirmed publish snapshot. Manual input is labelled
/// as such; it never claims that a health platform was connected.
final class CardComposerScreen extends ConsumerStatefulWidget {
  const CardComposerScreen({
    super.key,
    required this.squadId,
    required this.squadName,
  });

  final String squadId;
  final String squadName;

  @override
  ConsumerState<CardComposerScreen> createState() => _CardComposerScreenState();
}

final class _CardComposerScreenState extends ConsumerState<CardComposerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _distance = TextEditingController();
  final _duration = TextEditingController();
  final _heartRate = TextEditingController();
  final _weight = TextEditingController();
  final _sleep = TextEditingController();
  final _selectedMessageIds = <String>{};
  final _selectedFields = <String>{};
  CardKind _kind = CardKind.activity;
  String _activityType = 'run';
  DateTime _activityDate = DateTime.now();
  CardDraft? _previewDraft;
  List<String> _previewConversationLines = const [];
  bool _publishing = false;
  bool _loadingActivities = false;
  bool _loadingRoute = false;
  bool _shareRoute = false;
  ActivityRecord? _selectedActivity;
  _PendingCardPublish? _pendingPublish;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _distance,
      _duration,
      _heartRate,
      _weight,
      _sleep,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _invalidatePreview() {
    if (_previewDraft != null) setState(() => _previewDraft = null);
  }

  CardDraft _composeActivity() {
    final distanceKm = double.parse(_distance.text.trim());
    final durationMinutes = double.parse(_duration.text.trim());
    return CardComposer().draftFromActivity(
      activityType: _activityType,
      date: _activityDate,
      distanceMeters: distanceKm * 1000,
      durationSeconds: (durationMinutes * 60).round(),
      title: _title.text.trim(),
      averageHeartRateBpm: _heartRate.text.trim().isEmpty
          ? null
          : int.parse(_heartRate.text.trim()),
      weightKg: _weight.text.trim().isEmpty
          ? null
          : double.parse(_weight.text.trim()),
      sleepMinutes: _sleep.text.trim().isEmpty
          ? null
          : int.parse(_sleep.text.trim()),
      preciseRoute: _selectedActivity?.preciseRoute
          ?.map(
            (point) => RoutePoint(
              latitude: point.latitude,
              longitude: point.longitude,
            ),
          )
          .toList(),
    );
  }

  Future<void> _readSelectedRoute() async {
    final selected = _selectedActivity;
    if (selected == null || _loadingRoute) return;
    setState(() => _loadingRoute = true);
    try {
      final source =
          selected.source == ActivitySourceKind.gpxFile ||
              selected.source == ActivitySourceKind.fileImport
          ? ref.read(gpxActivitySourceProvider)
          : ref.read(healthActivitySourceProvider);
      final withRoute = await source.readPreciseRoute(selected);
      if (!mounted) return;
      setState(() {
        _selectedActivity = withRoute;
        _shareRoute = false;
        _previewDraft = null;
      });
      if ((withRoute.preciseRoute?.length ?? 0) < 2) {
        _showError('这条运动记录没有可用的精确路线');
      }
    } on ActivityPermissionDenied {
      _showError('未获得路线读取授权；可在系统设置中重新授权');
    } on ActivitySourceUnavailable {
      _showError('这条运动文件含多段轨迹，当前仅能分享距离和时长');
    } catch (_) {
      _showError('路线读取失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Future<void> _chooseHealthWorkout() async {
    if (_loadingActivities) return;
    setState(() => _loadingActivities = true);
    try {
      final now = DateTime.now();
      final activities = await ref
          .read(healthActivitySourceProvider)
          .listEligibleActivities(
            from: now.subtract(
              Duration(days: ref.read(healthActivityLookbackDaysProvider)),
            ),
            to: now,
          );
      if (!mounted) return;
      if (activities.isEmpty) {
        _showError(
          '没有读到近 ${ref.read(healthActivityLookbackDaysProvider)} 天可用的跑步或徒步记录；请检查系统健康数据和读取授权',
        );
        return;
      }
      final selected = await _pickActivity(activities);
      if (selected == null || !mounted) return;
      _useSelectedActivity(selected);
    } on ActivitySourceUnavailable {
      _showError('这台设备暂不支持健康数据读取，或 Health Connect 尚未安装');
    } on ActivityPermissionDenied {
      _showError('未获得运动记录读取授权；可在系统设置中重新授权');
    } catch (_) {
      _showError('读取运动记录失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loadingActivities = false);
    }
  }

  Future<void> _chooseGpxFile() async {
    if (_loadingActivities) return;
    setState(() => _loadingActivities = true);
    final source = ref.read(gpxActivitySourceProvider);
    try {
      final activities = await source.importFromDevice(
        kind: _activityType == 'run' ? ActivityKind.run : ActivityKind.hike,
      );
      if (activities == null || !mounted) return;
      final selected = await _pickActivity(activities);
      if (selected == null || !mounted) return;
      source.acceptSelection(selected.id);
      _useSelectedActivity(selected);
    } on FormatException {
      _showError('运动文件无可用的定时轨迹；请检查时间、坐标和文件大小');
    } catch (_) {
      _showError('导入运动文件失败，请稍后重试');
    } finally {
      source.discardCandidates();
      if (mounted) setState(() => _loadingActivities = false);
    }
  }

  Future<ActivityRecord?> _pickActivity(
    List<ActivityRecord> activities,
  ) => showModalBottomSheet<ActivityRecord>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('选择一条运动记录')),
            for (final activity in activities)
              ListTile(
                title: Text(
                  '${activity.kind == ActivityKind.run ? '跑步' : '徒步'} · '
                  '${(activity.distanceMeters / 1000).toStringAsFixed(2)} 公里',
                ),
                subtitle: Text(
                  '${ActivityMetrics.localCalendarDate(activity).year}-'
                  '${ActivityMetrics.localCalendarDate(activity).month}-'
                  '${ActivityMetrics.localCalendarDate(activity).day} · '
                  '${(activity.durationSeconds / 60).round()} 分钟 · '
                  '${activity.sourceLabel}',
                ),
                onTap: () => Navigator.pop(context, activity),
              ),
          ],
        ),
      ),
    ),
  );

  void _useSelectedActivity(ActivityRecord selected) {
    setState(() {
      _selectedActivity = selected;
      _shareRoute = false;
      _activityType = selected.kind == ActivityKind.run ? 'run' : 'hike';
      _activityDate = ActivityMetrics.localCalendarDate(selected);
      _distance.text = (selected.distanceMeters / 1000).toStringAsFixed(2);
      _duration.text = (selected.durationSeconds / 60).toStringAsFixed(1);
      _title.text = selected.kind == ActivityKind.run ? '今天的跑步' : '今天的徒步';
      if (selected.averageHeartRateBpm case final heartRate?) {
        _heartRate.text = heartRate.toString();
      } else {
        _heartRate.clear();
      }
      _weight.clear();
      _sleep.clear();
      _selectedFields.clear();
      _previewDraft = null;
    });
  }

  CardDraft _composeConversation() {
    final controller = ref.read(
      conversationControllerProvider(
        ConversationTarget(squadId: widget.squadId),
      ).notifier,
    );
    final entries = ref
        .read(
          conversationControllerProvider(
            ConversationTarget(squadId: widget.squadId),
          ),
        )
        .entries;
    final selected = [
      for (final entry in entries)
        if (_selectedMessageIds.contains(entry.id))
          SelectedChatMessage(
            id: entry.id,
            squadId: entry.squadId,
            authorId: entry.authorId,
            text: entry.text ?? '',
          ),
    ];
    _previewConversationLines = [for (final message in selected) message.text];
    return CardComposer().draftFromMessages(
      squadId: widget.squadId,
      authorId: controller.currentUserId,
      selected: selected,
    );
  }

  void _preview() {
    if (_kind == CardKind.activity && !_formKey.currentState!.validate()) {
      return;
    }
    try {
      final draft = _kind == CardKind.activity
          ? _composeActivity()
          : _composeConversation();
      setState(() => _previewDraft = draft);
    } on FormatException {
      _showError('请检查数字格式');
    } on ArgumentError {
      _showError('请检查运动记录数值');
    } on StateError {
      _showError('请选择 1–6 条你自己发送的文字消息');
    }
  }

  Future<void> _publish() async {
    final draft = _previewDraft;
    if (draft == null || _publishing) return;
    final confirmed = draft.confirm(selectedFields: _selectedFields);
    final route = _kind == CardKind.activity && _shareRoute
        ? _selectedActivity?.preciseRoute
        : null;
    if (_shareRoute && (route == null || route.length < 2)) {
      _showError('请先读取这条记录的精确路线');
      return;
    }
    final snapshot = route != null
        ? CardSnapshot(
            kind: confirmed.kind,
            payload: confirmed.payload,
            templateId: confirmed.templateId,
            templateVersion: confirmed.templateVersion,
            hasEncryptedRoute: true,
          )
        : confirmed;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认发布到小队？'),
        content: Text(
          '接收者：${widget.squadName}的小队成员\n'
          '内容：${snapshot.kind == CardKind.activity ? snapshot.payload['title'] : '所选的 ${_selectedMessageIds.length} 条本人消息'}\n'
          '已选择的敏感字段：${_selectedFields.isEmpty ? '无' : _selectedFields.map(_fieldLabel).join('、')}\n\n'
          '精确轨迹：${_shareRoute ? '已选择；仅在核对队友设备后加密上传' : '不分享'}\n\n'
          '发布后队友可在小队中查看；导出到其他聊天工具的图片无法远程撤回。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再检查一下'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认发布'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _publishing = true);
    try {
      final previous = _pendingPublish;
      final retry = previous != null && previous.matches(snapshot, route);
      final cardId = retry ? previous.cardId : const Uuid().v4();
      EncryptedRouteBundle? encryptedRoute = retry
          ? previous.encryptedRoute
          : null;
      if (route != null && !retry) {
        final approvedKeys = await _approveRouteRecipients();
        if (approvedKeys == null || !mounted) return;
        final userId = ref.read(currentUserProvider).value?.id;
        if (userId == null) throw StateError('Not signed in');
        encryptedRoute = await ref
            .read(routeEncryptionServiceProvider)
            .prepare(
              userId: userId,
              squadId: widget.squadId,
              cardId: cardId,
              templateVersion: snapshot.templateVersion,
              route: route,
              approvedPublicKeys: approvedKeys,
              explicitlyConfirmed: true,
            );
      }
      if (!retry) {
        _pendingPublish = _PendingCardPublish(
          cardId: cardId,
          snapshot: snapshot,
          route: route,
          encryptedRoute: encryptedRoute,
        );
      }
      final result = await ref
          .read(
            conversationControllerProvider(
              ConversationTarget(squadId: widget.squadId),
            ).notifier,
          )
          .publishCard(
            cardId: cardId,
            snapshot: snapshot,
            encryptedRoute: encryptedRoute,
          );
      if (!mounted) return;
      result.match((_) => _showError('发布失败，请检查网络和小队权限'), (_) {
        _pendingPublish = null;
        Navigator.of(context).pop(true);
      });
    } on UntrustedRouteDeviceException {
      _showError('设备密钥已变化或未核对；本次卡片未发布');
    } catch (_) {
      _showError('路线加密或发布失败；本次卡片未发布');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<Map<String, String>?> _approveRouteRecipients() async {
    final userId = ref.read(currentUserProvider).value?.id;
    if (userId == null) throw StateError('Not signed in');
    final keyStore = ref.read(routeDeviceKeyStoreProvider);
    final directory = ref.read(routeKeyDirectoryProvider);
    final ownKey = await keyStore.loadOrCreate(userId: userId);
    await directory.registerDevice(
      RouteRecipient(
        userId: userId,
        deviceId: ownKey.deviceId,
        publicKeyBase64: ownKey.publicKeyBase64,
      ),
    );
    final recipients = await directory.listRecipients(widget.squadId);
    final members = await ref.read(squadMembersProvider(widget.squadId).future);
    final memberIds = members.map((member) => member.userId).toSet();
    final recipientIds = recipients
        .map((recipient) => recipient.userId)
        .toSet();
    if (recipientIds.length != memberIds.length ||
        !recipientIds.containsAll(memberIds) ||
        !recipients.any(
          (entry) =>
              entry.deviceId == ownKey.deviceId &&
              entry.userId == userId &&
              entry.publicKeyBase64 == ownKey.publicKeyBase64,
        )) {
      throw const UntrustedRouteDeviceException();
    }
    final otherDevices = recipients
        .where((recipient) => recipient.deviceId != ownKey.deviceId)
        .toList();
    if (otherDevices.isEmpty) throw const UntrustedRouteDeviceException();
    final fingerprints = <String, String>{};
    for (final recipient in otherDevices) {
      fingerprints[recipient.deviceId] = await RouteFingerprint.ofPublicKey(
        recipient.publicKeyBase64,
      );
    }
    if (!mounted) return null;
    final checked = <String>{};
    final didApprove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('逐台核对路线接收设备'),
          content: SizedBox(
            width: 520,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text('请让队友打开“路线设备”，通过当面或可信渠道比对完整指纹；仅点选已核对的设备。'),
                const SizedBox(height: 12),
                for (final recipient in otherDevices)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: checked.contains(recipient.deviceId),
                    title: Text(
                      recipient.userId == userId
                          ? '我的其他设备'
                          : members
                                    .where(
                                      (member) =>
                                          member.userId == recipient.userId,
                                    )
                                    .firstOrNull
                                    ?.nickname ??
                                '队友设备',
                    ),
                    subtitle: SelectableText(fingerprints[recipient.deviceId]!),
                    onChanged: (value) => setDialogState(() {
                      if (value == true) {
                        checked.add(recipient.deviceId);
                      } else {
                        checked.remove(recipient.deviceId);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消发布'),
            ),
            FilledButton(
              onPressed: checked.length == otherDevices.length
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('已逐台核对并加密'),
            ),
          ],
        ),
      ),
    );
    if (didApprove != true) return null;
    return {
      for (final recipient in otherDevices)
        recipient.deviceId: recipient.publicKeyBase64,
    };
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Keep the conversation controller (and its pending publish nonce) alive
    // for the entire composer session, including activity-card retries.
    ref.watch(
      conversationControllerProvider(
        ConversationTarget(squadId: widget.squadId),
      ),
    );
    final preview = _previewDraft;
    return Scaffold(
      appBar: AppBar(title: const Text('生成卡片')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Text(
                '发布到 ${widget.squadName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('运动记录卡'),
                    selected: _kind == CardKind.activity,
                    onSelected: (_) => setState(() {
                      _kind = CardKind.activity;
                      _previewDraft = null;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('群聊内容卡'),
                    selected: _kind == CardKind.conversation,
                    onSelected: (_) => setState(() {
                      _kind = CardKind.conversation;
                      _shareRoute = false;
                      _previewDraft = null;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_kind == CardKind.activity)
                _activityForm()
              else
                _conversationPicker(),
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: _preview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('预览卡片'),
              ),
              if (preview != null) ...[
                const SizedBox(height: 20),
                CardPreview(
                  squadName: widget.squadName,
                  snapshot: preview.confirm(selectedFields: _selectedFields),
                  conversationLines: _previewConversationLines,
                  preciseRoute: _shareRoute
                      ? [
                          for (final point
                              in _selectedActivity?.preciseRoute ??
                                  const <RouteCoordinate>[])
                            RoutePoint(
                              latitude: point.latitude,
                              longitude: point.longitude,
                            ),
                        ]
                      : const [],
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _publishing ? null : _publish,
                  child: Text(_publishing ? '正在发布…' : '确认发布到小队'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityForm() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('activity_type_$_activityType'),
          initialValue: _activityType,
          decoration: const InputDecoration(labelText: '运动类型'),
          items: const [
            DropdownMenuItem(value: 'run', child: Text('跑步')),
            DropdownMenuItem(value: 'hike', child: Text('徒步')),
          ],
          onChanged: (value) => setState(() {
            _activityType = value ?? 'run';
            _previewDraft = null;
          }),
        ),
        const SizedBox(height: 12),
        if (ref
            .watch(healthActivityAvailableProvider)
            .maybeWhen(
              data: (available) => available,
              orElse: () => false,
            )) ...[
          OutlinedButton.icon(
            onPressed: _loadingActivities ? null : _chooseHealthWorkout,
            icon: const Icon(Icons.directions_run_outlined),
            label: Text(
              _loadingActivities
                  ? '正在读取…'
                  : '从 ${ref.watch(healthActivitySourceLabelProvider)}选择记录',
            ),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _loadingActivities ? null : _chooseGpxFile,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(
            _loadingActivities ? '正在读取…' : '导入 GPX／TCX／KML 文件（运动类型按当前选择）',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _selectedActivity == null
              ? '手工补正或录入真实运动记录 · 仅发布你确认的字段'
              : '来源：${_selectedActivity!.sourceLabel} · 可手工补正',
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final firstDate = DateTime(2010);
            final lastDate = DateTime.now();
            final pickerDate = _activityDate.isBefore(firstDate)
                ? firstDate
                : _activityDate.isAfter(lastDate)
                ? lastDate
                : _activityDate;
            final picked = await showDatePicker(
              context: context,
              initialDate: pickerDate,
              firstDate: firstDate,
              lastDate: lastDate,
            );
            if (picked != null) {
              setState(() {
                _activityDate = picked;
                _previewDraft = null;
              });
            }
          },
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            '运动日期：${_activityDate.year}-${_activityDate.month}-${_activityDate.day}',
          ),
        ),
        _field(_title, '标题', required: true),
        _field(_distance, '距离（公里）', required: true, numeric: true),
        _field(_duration, '时长（分钟）', required: true, numeric: true),
        _field(_heartRate, '平均心率（可选）', numeric: true),
        _field(_weight, '体重（可选）', numeric: true),
        _field(_sleep, '睡眠（分钟，可选）', numeric: true),
        if (_heartRate.text.trim().isNotEmpty)
          _sensitiveToggle('heart_rate', '分享平均心率'),
        if (_weight.text.trim().isNotEmpty) _sensitiveToggle('weight', '分享体重'),
        if (_sleep.text.trim().isNotEmpty) _sensitiveToggle('sleep', '分享睡眠'),
        if (_selectedActivity != null &&
            _selectedActivity!.source != ActivitySourceKind.healthConnect)
          OutlinedButton.icon(
            onPressed: _loadingRoute ? null : _readSelectedRoute,
            icon: const Icon(Icons.route_outlined),
            label: Text(_loadingRoute ? '正在读取路线…' : '读取这条记录的精确路线'),
          ),
        CheckboxListTile(
          value: _shareRoute,
          onChanged: (_selectedActivity?.preciseRoute?.length ?? 0) >= 2
              ? (checked) => setState(() {
                  _shareRoute = checked == true;
                  _previewDraft = null;
                })
              : null,
          title: const Text('分享精确轨迹'),
          subtitle: const Text('默认不分享；逐张确认、逐台核对后仅上传密文'),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) {
        _invalidatePreview();
        setState(() {});
      },
      validator: (value) {
        final input = value?.trim() ?? '';
        if (required && input.isEmpty) return '请填写$label';
        if (numeric && input.isNotEmpty && double.tryParse(input) == null) {
          return '请输入数字';
        }
        return null;
      },
    ),
  );

  Widget _sensitiveToggle(String field, String label) => CheckboxListTile(
    value: _selectedFields.contains(field),
    onChanged: (checked) => setState(() {
      if (checked == true) {
        _selectedFields.add(field);
      } else {
        _selectedFields.remove(field);
      }
    }),
    title: Text(label),
    subtitle: const Text('默认不分享；勾选后会进入小队可见的发布快照'),
    contentPadding: EdgeInsets.zero,
  );

  Widget _conversationPicker() {
    final controller = ref.read(
      conversationControllerProvider(
        ConversationTarget(squadId: widget.squadId),
      ).notifier,
    );
    final entries = ref
        .watch(
          conversationControllerProvider(
            ConversationTarget(squadId: widget.squadId),
          ),
        )
        .entries;
    final myMessages = entries
        .where(
          (entry) =>
              entry.kind == TimelineEntryKind.text &&
              entry.authorId == controller.currentUserId,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('选择 1–6 条你自己发送的消息；不会自动总结或引用他人原话。'),
        if (myMessages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('先在小队聊天中发送文字消息，再来制作群聊卡。'),
          )
        else
          for (final entry in myMessages.reversed)
            CheckboxListTile(
              value: _selectedMessageIds.contains(entry.id),
              title: Text(
                entry.text ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selectedMessageIds.add(entry.id);
                } else {
                  _selectedMessageIds.remove(entry.id);
                }
                _previewDraft = null;
              }),
            ),
      ],
    );
  }

  static String _fieldLabel(String field) => switch (field) {
    'heart_rate' => '心率',
    'weight' => '体重',
    'sleep' => '睡眠',
    _ => field,
  };
}

final class _PendingCardPublish {
  const _PendingCardPublish({
    required this.cardId,
    required this.snapshot,
    required this.route,
    required this.encryptedRoute,
  });

  final String cardId;
  final CardSnapshot snapshot;
  final List<RouteCoordinate>? route;
  final EncryptedRouteBundle? encryptedRoute;

  bool matches(CardSnapshot other, List<RouteCoordinate>? otherRoute) {
    if (snapshot.kind != other.kind ||
        snapshot.templateId != other.templateId ||
        snapshot.templateVersion != other.templateVersion ||
        snapshot.hasEncryptedRoute != other.hasEncryptedRoute ||
        jsonEncode(snapshot.payload) != jsonEncode(other.payload)) {
      return false;
    }
    if (route == null || otherRoute == null) {
      return route == null && otherRoute == null;
    }
    if (route!.length != otherRoute.length) return false;
    for (var index = 0; index < route!.length; index++) {
      if (route![index].latitude != otherRoute[index].latitude ||
          route![index].longitude != otherRoute[index].longitude) {
        return false;
      }
    }
    return true;
  }
}
