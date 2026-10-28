import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../app/providers/squad_context_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_loading_state.dart';
import '../../../squad/domain/entities/squad_member.dart';
import '../../domain/entities/plan_progress.dart';
import '../../domain/entities/plan_task.dart';
import '../../domain/entities/squad_plan.dart';
import '../providers/plan_provider.dart';

class PlanHomeScreen extends ConsumerWidget {
  const PlanHomeScreen({
    this.isDemo = false,
    this.onOpenScenario,
    this.onOpenPlanDiscussion,
    this.onOpenSquads,
    super.key,
  });

  final bool isDemo;
  final ValueChanged<PlanCategory>? onOpenScenario;
  final ValueChanged<SquadPlan>? onOpenPlanDiscussion;
  final VoidCallback? onOpenSquads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDemo) {
      final squad = ref.watch(demoAppStoreProvider).currentSquad;
      return squad == null
          ? _NoSquadState(onOpenSquads: onOpenSquads)
          : _PlanList(
              isDemo: true,
              squadId: squad.id,
              squadName: squad.name,
              onOpenScenario: onOpenScenario,
              onOpenPlanDiscussion: onOpenPlanDiscussion,
            );
    }
    final squad = ref.watch(currentSquadProvider);
    return squad.when(
      loading: () => const Center(child: AppLoadingState(label: '正在加载小队')),
      error: (_, _) => _RetryState(
        message: '小队加载失败',
        onRetry: () => ref.invalidate(mySquadsProvider),
      ),
      data: (current) => current == null
          ? _NoSquadState(onOpenSquads: onOpenSquads)
          : _PlanList(
              isDemo: false,
              squadId: current.id,
              squadName: current.name,
              onOpenScenario: onOpenScenario,
              onOpenPlanDiscussion: onOpenPlanDiscussion,
            ),
    );
  }
}

class _PlanList extends ConsumerStatefulWidget {
  const _PlanList({
    required this.isDemo,
    required this.squadId,
    required this.squadName,
    required this.onOpenScenario,
    required this.onOpenPlanDiscussion,
  });

  final bool isDemo;
  final String squadId;
  final String squadName;
  final ValueChanged<PlanCategory>? onOpenScenario;
  final ValueChanged<SquadPlan>? onOpenPlanDiscussion;

  @override
  ConsumerState<_PlanList> createState() => _PlanListState();
}

class _PlanListState extends ConsumerState<_PlanList> {
  PlanStatus? _filter = PlanStatus.active;
  bool _showTemplates = false;
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(squadPlansProvider(widget.squadId));
    final progress = ref.watch(squadPlanProgressProvider(widget.squadId));
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait<void>([
          ref
              .refresh(squadPlansProvider(widget.squadId).future)
              .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
          ref
              .refresh(squadPlanProgressProvider(widget.squadId).future)
              .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
        ]);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.mdLg,
              AppSpacing.mdLg,
              AppSpacing.mdLg,
              AppSpacing.xs,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '计划',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.groups_rounded,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                widget.squadName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _creating ? null : _createPlan,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('创建'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: _statusLabel(PlanStatus.active),
                    selected: !_showTemplates && _filter == PlanStatus.active,
                    onSelected: () => setState(() {
                      _showTemplates = false;
                      _filter = PlanStatus.active;
                    }),
                  ),
                  _FilterChip(
                    label: _statusLabel(PlanStatus.completed),
                    selected:
                        !_showTemplates && _filter == PlanStatus.completed,
                    onSelected: () => setState(() {
                      _showTemplates = false;
                      _filter = PlanStatus.completed;
                    }),
                  ),
                  _FilterChip(
                    label: '模板',
                    selected: _showTemplates,
                    onSelected: () => setState(() => _showTemplates = true),
                  ),
                  _FilterChip(
                    label: '全部',
                    selected: !_showTemplates && _filter == null,
                    onSelected: () => setState(() {
                      _showTemplates = false;
                      _filter = null;
                    }),
                  ),
                  _FilterChip(
                    label: _statusLabel(PlanStatus.archived),
                    selected: !_showTemplates && _filter == PlanStatus.archived,
                    onSelected: () => setState(() {
                      _showTemplates = false;
                      _filter = PlanStatus.archived;
                    }),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 78,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  _ScenarioButton(
                    label: '健身',
                    icon: Icons.directions_run_rounded,
                    onTap: () =>
                        widget.onOpenScenario?.call(PlanCategory.fitness),
                  ),
                  _ScenarioButton(
                    label: '理财',
                    icon: Icons.savings_outlined,
                    onTap: () =>
                        widget.onOpenScenario?.call(PlanCategory.finance),
                  ),
                  _ScenarioButton(
                    label: '旅行',
                    icon: Icons.map_outlined,
                    onTap: () =>
                        widget.onOpenScenario?.call(PlanCategory.travel),
                  ),
                  _ScenarioButton(
                    label: '美食',
                    icon: Icons.restaurant_outlined,
                    onTap: () => widget.onOpenScenario?.call(PlanCategory.food),
                  ),
                ],
              ),
            ),
          ),
          if (_showTemplates)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList.separated(
                itemCount: _planTemplates.length,
                itemBuilder: (context, index) {
                  final template = _planTemplates[index];
                  return _PlanTemplateCard(
                    template: template,
                    onTap: _creating
                        ? null
                        : () => _createPlan(
                            category: template.category,
                            suggestedTitle: template.suggestedTitle,
                          ),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 10),
              ),
            )
          else
            plans.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: AppLoadingState(label: '正在加载计划')),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _RetryState(
                  message: _readFailureMessage(error, '计划加载失败'),
                  onRetry: () =>
                      ref.invalidate(squadPlansProvider(widget.squadId)),
                ),
              ),
              data: (allPlans) {
                final filtered = allPlans
                    .where((plan) => _filter == null || plan.status == _filter)
                    .toList(growable: false);
                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyPlans(
                      hasPlans: allPlans.isNotEmpty,
                      onCreate: _creating ? null : _createPlan,
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _PlanCard(
                      plan: filtered[index],
                      progress: progress.value?[filtered[index].id],
                      progressLoaded: progress.hasValue,
                      progressUnavailable: progress.hasError,
                      onTap: () => _openPlan(filtered[index]),
                    ),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _createPlan({
    PlanCategory category = PlanCategory.custom,
    String? suggestedTitle,
  }) async {
    final data = await showDialog<_PlanDraft>(
      context: context,
      builder: (_) => _CreatePlanDialog(
        initialCategory: category,
        suggestedTitle: suggestedTitle,
      ),
    );
    if (data == null || !mounted) return;
    setState(() => _creating = true);
    final result = await ref
        .read(planRepositoryProvider)
        .createPlan(
          squadId: widget.squadId,
          title: data.title,
          category: data.category,
          visibility: data.visibility,
          description: data.description,
          startDate: data.startDate,
          endDate: data.endDate,
        );
    if (!mounted) return;
    setState(() => _creating = false);
    result.match(
      (failure) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_failureMessage(failure)))),
      (plan) {
        setState(() {
          _showTemplates = false;
          _filter = PlanStatus.active;
        });
        ref.invalidate(squadPlansProvider(widget.squadId));
        ref.invalidate(squadPlanProgressProvider(widget.squadId));
        _openPlan(plan);
      },
    );
  }

  void _openPlan(SquadPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanDetailScreen(
          plan: plan,
          isDemo: widget.isDemo,
          onOpenDiscussion: widget.onOpenPlanDiscussion,
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.progress,
    required this.progressLoaded,
    required this.progressUnavailable,
    required this.onTap,
  });

  final SquadPlan plan;
  final PlanProgress? progress;
  final bool progressLoaded;
  final bool progressUnavailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _categoryIcon(plan.category),
                    color: context.squadlyPalette.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      plan.title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              if (plan.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  plan.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Tag(label: _categoryLabel(plan.category)),
                  _Tag(
                    label: plan.visibility == PlanVisibility.private
                        ? '仅自己可见'
                        : '小队可见',
                    icon: plan.visibility == PlanVisibility.private
                        ? Icons.lock_outline_rounded
                        : Icons.groups_outlined,
                  ),
                  _Tag(label: _statusLabel(plan.status)),
                ],
              ),
              if (plan.startDate != null || plan.endDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  _dateRange(plan.startDate, plan.endDate),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
              if (progressLoaded || progressUnavailable) ...[
                const SizedBox(height: 12),
                if (progressUnavailable)
                  Text(
                    '进度暂不可用',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  )
                else if (progress?.fraction == null)
                  Text(
                    '暂无任务',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  )
                else ...[
                  Row(
                    children: [
                      Text(
                        '任务进度',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const Spacer(),
                      Text(
                        '${progress!.completedCount}/${progress!.totalCount}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress!.fraction,
                    color: context.squadlyPalette.accent,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({
    required this.plan,
    this.isDemo = false,
    this.onOpenDiscussion,
    super.key,
  });

  final SquadPlan plan;
  final bool isDemo;
  final ValueChanged<SquadPlan>? onOpenDiscussion;

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  bool _adding = false;
  late SquadPlan _plan;
  late PlanStatus _status;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    _status = widget.plan.status;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(planTasksProvider(_plan.id));
    final taskItems = tasks.value;
    final plan = _plan;
    final legacyData = plan.legacyData;
    final colors = Theme.of(context).colorScheme;
    final members = widget.isDemo
        ? ref.watch(demoAppStoreProvider).membersFor(plan.squadId)
        : ref.watch(squadMembersProvider(plan.squadId)).value ??
              const <SquadMember>[];
    final memberNames = {
      for (final member in members) member.userId: member.nickname ?? '小队成员',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划详情'),
        actions: [
          IconButton(
            tooltip: '编辑计划',
            onPressed: _editPlan,
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<PlanStatus>(
            tooltip: '更新计划状态',
            onSelected: _setPlanStatus,
            itemBuilder: (context) => [
              for (final status in PlanStatus.values.where(
                (status) => status != _status,
              ))
                PopupMenuItem(value: status, child: Text(_statusLabel(status))),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(planTasksProvider(plan.id)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Tag(label: _categoryLabel(plan.category)),
                        _Tag(
                          label: plan.visibility == PlanVisibility.private
                              ? '仅自己可见'
                              : '小队可见',
                          icon: plan.visibility == PlanVisibility.private
                              ? Icons.lock_outline_rounded
                              : Icons.groups_outlined,
                        ),
                        _Tag(label: _statusLabel(_status)),
                      ],
                    ),
                    if (plan.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 14),
                      Text(plan.description!),
                    ],
                    if (plan.legacySource != null) ...[
                      const SizedBox(height: 16),
                      _LegacyPlanDetails(
                        source: plan.legacySource!,
                        data: legacyData,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      plan.visibility == PlanVisibility.private
                          ? '仅你可以查看此计划和其中的任务。计划仍归属当前小队。'
                          : '当前小队成员可以查看此计划和其中的任务。',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 22),
                    if (!widget.isDemo && widget.onOpenDiscussion != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openDiscussion,
                          icon: const Icon(Icons.forum_outlined),
                          label: const Text('进入计划讨论'),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '任务',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _adding ? null : _addTask,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('添加任务'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (taskItems != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _TaskProgress(tasks: taskItems),
                ),
              ),
            tasks.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: AppLoadingState(label: '正在加载任务')),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: _RetryState(
                  message: _readFailureMessage(error, '任务加载失败'),
                  onRetry: () => ref.invalidate(planTasksProvider(plan.id)),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const SliverToBoxAdapter(child: _EmptyTasks())
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        itemBuilder: (context, index) => _TaskTile(
                          task: items[index],
                          assignedToName: memberNames[items[index].assignedTo],
                          onChanged: (complete) =>
                              _setTaskComplete(items[index], complete),
                        ),
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDiscussion() => widget.onOpenDiscussion?.call(_plan);

  Future<void> _addTask() async {
    List<SquadMember> members;
    try {
      members = widget.isDemo
          ? ref.read(demoAppStoreProvider).membersFor(_plan.squadId)
          : await ref.read(squadMembersProvider(_plan.squadId).future);
    } catch (_) {
      if (mounted) _showFailure('小队成员加载失败，请重试');
      return;
    }
    if (!mounted) return;
    final draft = await showDialog<_TaskDraft>(
      context: context,
      builder: (_) => _CreateTaskDialog(members: members),
    );
    if (draft == null || !mounted) return;
    setState(() => _adding = true);
    final result = await ref
        .read(planRepositoryProvider)
        .createTask(
          planId: _plan.id,
          squadId: _plan.squadId,
          title: draft.title,
          details: draft.details,
          assignedTo: draft.assignedTo,
          dueDate: draft.dueDate,
        );
    if (!mounted) return;
    setState(() => _adding = false);
    result.match((failure) => _showFailure(failure), (_) {
      ref.invalidate(planTasksProvider(_plan.id));
      ref.invalidate(squadPlanProgressProvider(_plan.squadId));
    });
  }

  Future<void> _setTaskComplete(PlanTask task, bool isComplete) async {
    final result = await ref
        .read(planRepositoryProvider)
        .setTaskCompletion(taskId: task.id, isComplete: isComplete);
    if (!mounted) return;
    result.match((failure) => _showFailure(failure), (_) {
      ref.invalidate(planTasksProvider(_plan.id));
      ref.invalidate(squadPlanProgressProvider(_plan.squadId));
    });
  }

  Future<void> _setPlanStatus(PlanStatus status) async {
    final result = await ref
        .read(planRepositoryProvider)
        .setPlanStatus(planId: _plan.id, status: status);
    if (!mounted) return;
    result.match((failure) => _showFailure(failure), (_) {
      setState(() => _status = status);
      ref.invalidate(squadPlansProvider(_plan.squadId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('计划已更新为${_statusLabel(status)}')));
    });
  }

  Future<void> _editPlan() async {
    final data = await showDialog<_PlanDraft>(
      context: context,
      builder: (_) => _CreatePlanDialog(initialPlan: _plan),
    );
    if (data == null || !mounted) return;
    final result = await ref
        .read(planRepositoryProvider)
        .updatePlan(
          planId: _plan.id,
          title: data.title,
          category: data.category,
          visibility: data.visibility,
          description: data.description,
          startDate: data.startDate,
          endDate: data.endDate,
        );
    if (!mounted) return;
    result.match((failure) => _showFailure(failure), (updated) {
      setState(() {
        _plan = updated;
        _status = updated.status;
      });
      ref.invalidate(squadPlansProvider(_plan.squadId));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('计划已更新')));
    });
  }

  void _showFailure(Object failure) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_failureMessage(failure))));
  }
}

class _LegacyPlanDetails extends StatelessWidget {
  const _LegacyPlanDetails({required this.source, required this.data});

  final String source;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final destination = data['destination'] as String?;
    final budget = data['budget'];
    final planType = data['plan_type'] as String?;
    final lines = <String>[
      if (destination?.isNotEmpty == true) '目的地：$destination',
      if (budget is num) '原预算：${budget.toStringAsFixed(0)}',
      if (planType?.isNotEmpty == true)
        '原计划类型：${_legacyFitnessType(planType!)}',
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source == 'travel_plan' ? '已迁移的旅行计划' : '已迁移的健身计划',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(line),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _legacyFitnessType(String value) => switch (value) {
  'muscle_gain' => '增肌',
  'fat_loss' => '减脂',
  'body_shaping' => '塑形',
  'custom' => '自定义',
  _ => value,
};

class _TaskProgress extends StatelessWidget {
  const _TaskProgress({required this.tasks});

  final List<PlanTask> tasks;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completed = tasks.where((task) => task.isComplete).length;
    final fraction = tasks.isEmpty ? null : completed / tasks.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: fraction == null
            ? Text(
                '暂无任务，添加任务后会显示进度',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('任务进度')),
                      Text('$completed/${tasks.length} 已完成'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: fraction,
                    color: context.squadlyPalette.accent,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                ],
              ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.assignedToName,
    required this.onChanged,
  });

  final PlanTask task;
  final String? assignedToName;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: CheckboxListTile(
      value: task.isComplete,
      onChanged: (value) => onChanged(value ?? false),
      title: Text(task.title),
      subtitle: task.details?.isNotEmpty == true
          ? Text(
              [
                task.details!,
                if (assignedToName != null) '负责人：$assignedToName',
                if (task.dueDate != null) '截止 ${_date(task.dueDate!)}',
              ].join(' · '),
            )
          : [
              if (assignedToName != null) '负责人：$assignedToName',
              if (task.dueDate != null) '截止 ${_date(task.dueDate!)}',
            ].isEmpty
          ? null
          : Text(
              [
                if (assignedToName != null) '负责人：$assignedToName',
                if (task.dueDate != null) '截止 ${_date(task.dueDate!)}',
              ].join(' · '),
            ),
      controlAffinity: ListTileControlAffinity.leading,
      secondary: task.assignedTo == null
          ? null
          : const Tooltip(
              message: '已分配成员',
              child: Icon(Icons.person_outline_rounded),
            ),
    ),
  );
}

class _CreatePlanDialog extends StatefulWidget {
  const _CreatePlanDialog({
    this.initialPlan,
    this.initialCategory,
    this.suggestedTitle,
  });

  final SquadPlan? initialPlan;
  final PlanCategory? initialCategory;
  final String? suggestedTitle;

  @override
  State<_CreatePlanDialog> createState() => _CreatePlanDialogState();
}

class _CreatePlanDialogState extends State<_CreatePlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  PlanCategory _category = PlanCategory.custom;
  PlanVisibility _visibility = PlanVisibility.squad;
  DateTime? _startDate;
  DateTime? _endDate;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    final plan = widget.initialPlan;
    if (plan == null) {
      _category = widget.initialCategory ?? PlanCategory.custom;
      _title.text = widget.suggestedTitle ?? '';
      return;
    }
    _title.text = plan.title;
    _description.text = plan.description ?? '';
    _category = plan.category;
    _visibility = plan.visibility;
    _startDate = plan.startDate;
    _endDate = plan.endDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialPlan != null;
    return AlertDialog(
      title: Text(editing ? '编辑计划' : '创建计划'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: _step == 0 ? 0.5 : 1),
                const SizedBox(height: 8),
                Text(
                  _step == 0 ? '第 1 步 · 基本信息' : '第 2 步 · 协作设置',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 12),
                if (_step == 0)
                  _basicInformationStep()
                else
                  _collaborationStep(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        if (_step == 1)
          TextButton(
            onPressed: () => setState(() => _step = 0),
            child: const Text('上一步'),
          ),
        FilledButton(
          onPressed: _step == 0 ? _continueToCollaboration : _submit,
          child: Text(
            _step == 0
                ? '下一步'
                : editing
                ? '保存修改'
                : '创建计划',
          ),
        ),
      ],
    );
  }

  Widget _basicInformationStep() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextFormField(
        controller: _title,
        autofocus: widget.initialPlan == null,
        maxLength: 100,
        decoration: const InputDecoration(labelText: '计划名称'),
        validator: (value) =>
            value == null || value.trim().isEmpty ? '请输入计划名称' : null,
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<PlanCategory>(
        initialValue: _category,
        decoration: const InputDecoration(labelText: '计划类型'),
        items: [
          for (final category in PlanCategory.values)
            DropdownMenuItem(
              value: category,
              child: Text(_categoryLabel(category)),
            ),
        ],
        onChanged: (value) =>
            setState(() => _category = value ?? PlanCategory.custom),
      ),
    ],
  );

  Widget _collaborationStep() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextFormField(
        controller: _description,
        maxLength: 500,
        maxLines: 2,
        decoration: const InputDecoration(labelText: '计划描述（选填）'),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<PlanVisibility>(
        initialValue: _visibility,
        decoration: const InputDecoration(labelText: '可见范围'),
        items: const [
          DropdownMenuItem(value: PlanVisibility.squad, child: Text('当前小队可见')),
          DropdownMenuItem(value: PlanVisibility.private, child: Text('仅自己可见')),
        ],
        onChanged: (value) =>
            setState(() => _visibility = value ?? PlanVisibility.squad),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _selectDates,
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(
          _startDate == null && _endDate == null
              ? '设置计划时间（选填）'
              : _dateRange(_startDate, _endDate),
        ),
      ),
      if (_startDate != null || _endDate != null)
        TextButton(
          onPressed: () => setState(() {
            _startDate = null;
            _endDate = null;
          }),
          child: const Text('清除日期'),
        ),
      const SizedBox(height: 8),
      Text(
        _visibility == PlanVisibility.private
            ? '计划仍关联当前小队，仅你可以查看。'
            : '当前小队成员可以查看计划内容。',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  void _continueToCollaboration() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _step = 1);
  }

  void _submit() {
    Navigator.pop(
      context,
      _PlanDraft(
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category,
        visibility: _visibility,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
  }

  Future<void> _selectDates() async {
    final start = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择开始日期',
    );
    if (start == null || !mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate: _endDate != null && !_endDate!.isBefore(start)
          ? _endDate!
          : start,
      firstDate: start,
      lastDate: DateTime(2100),
      helpText: '选择结束日期（选填）',
    );
    if (!mounted) return;
    setState(() {
      _startDate = start;
      _endDate = end;
    });
  }
}

class _CreateTaskDialog extends StatefulWidget {
  const _CreateTaskDialog({required this.members});

  final List<SquadMember> members;

  @override
  State<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<_CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _details = TextEditingController();
  String? _assignedTo;
  DateTime? _dueDate;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('添加任务'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              autofocus: true,
              maxLength: 160,
              decoration: const InputDecoration(labelText: '任务名称'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入任务名称' : null,
            ),
            TextFormField(
              controller: _details,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '任务说明（选填）'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _assignedTo,
              decoration: const InputDecoration(labelText: '分配给（选填）'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('暂不分配'),
                ),
                for (final member in widget.members)
                  DropdownMenuItem<String?>(
                    value: member.userId,
                    child: Text(
                      member.nickname ?? '小队成员',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _assignedTo = value),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _selectDueDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _dueDate == null ? '设置截止日期（选填）' : '截止 ${_date(_dueDate!)}',
              ),
            ),
            if (_dueDate != null)
              TextButton(
                onPressed: () => setState(() => _dueDate = null),
                child: const Text('清除截止日期'),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _TaskDraft(
              title: _title.text.trim(),
              details: _details.text.trim(),
              assignedTo: _assignedTo,
              dueDate: _dueDate,
            ),
          );
        },
        child: const Text('添加'),
      ),
    ],
  );

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择任务截止日期',
    );
    if (!mounted || date == null) return;
    setState(() => _dueDate = date);
  }
}

class _PlanDraft {
  const _PlanDraft({
    required this.title,
    required this.category,
    required this.visibility,
    this.description,
    this.startDate,
    this.endDate,
  });

  final String title;
  final String? description;
  final PlanCategory category;
  final PlanVisibility visibility;
  final DateTime? startDate;
  final DateTime? endDate;
}

const _planTemplates = <_PlanTemplate>[
  _PlanTemplate(
    label: '健身计划',
    description: '安排训练目标和运动任务',
    suggestedTitle: '健身计划',
    category: PlanCategory.fitness,
    icon: Icons.fitness_center_rounded,
  ),
  _PlanTemplate(
    label: '理财计划',
    description: '规划小队公共基金目标',
    suggestedTitle: '小队理财计划',
    category: PlanCategory.finance,
    icon: Icons.savings_outlined,
  ),
  _PlanTemplate(
    label: '旅行计划',
    description: '整理行程安排与分工',
    suggestedTitle: '旅行计划',
    category: PlanCategory.travel,
    icon: Icons.flight_takeoff_rounded,
  ),
  _PlanTemplate(
    label: '美食计划',
    description: '安排聚餐与共同准备事项',
    suggestedTitle: '美食计划',
    category: PlanCategory.food,
    icon: Icons.restaurant_outlined,
  ),
  _PlanTemplate(
    label: '空白计划',
    description: '从标题和任务开始自定义',
    category: PlanCategory.custom,
    icon: Icons.description_outlined,
  ),
];

final class _PlanTemplate {
  const _PlanTemplate({
    required this.label,
    required this.description,
    required this.category,
    required this.icon,
    this.suggestedTitle,
  });

  final String label;
  final String description;
  final String? suggestedTitle;
  final PlanCategory category;
  final IconData icon;
}

class _PlanTemplateCard extends StatelessWidget {
  const _PlanTemplateCard({required this.template, required this.onTap});

  final _PlanTemplate template;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: context.squadlyPalette.accentSoft,
                foregroundColor: context.squadlyPalette.action,
                child: Icon(template.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.description,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskDraft {
  const _TaskDraft({
    required this.title,
    required this.details,
    required this.assignedTo,
    required this.dueDate,
  });

  final String title;
  final String details;
  final String? assignedTo;
  final DateTime? dueDate;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
}

class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 8, 10),
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    avatar: icon == null ? null : Icon(icon, size: 15),
    label: Text(label),
    padding: EdgeInsets.zero,
  );
}

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans({required this.hasPlans, required this.onCreate});

  final bool hasPlans;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasPlans ? Icons.filter_list_off_rounded : Icons.event_note_rounded,
            size: 44,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(hasPlans ? '这个分类下还没有计划' : '还没有计划'),
          if (!hasPlans) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('创建第一个计划'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Center(
      child: Text(
        '还没有任务',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

class _NoSquadState extends StatelessWidget {
  const _NoSquadState({required this.onOpenSquads});

  final VoidCallback? onOpenSquads;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('先创建或加入小队'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onOpenSquads, child: const Text('前往小队')),
        ],
      ),
    ),
  );
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
      ],
    ),
  );
}

String _categoryLabel(PlanCategory category) => switch (category) {
  PlanCategory.fitness => '健身',
  PlanCategory.finance => '理财',
  PlanCategory.travel => '旅行',
  PlanCategory.food => '美食',
  PlanCategory.custom => '空白计划',
};

IconData _categoryIcon(PlanCategory category) => switch (category) {
  PlanCategory.fitness => Icons.directions_run_rounded,
  PlanCategory.finance => Icons.savings_outlined,
  PlanCategory.travel => Icons.map_outlined,
  PlanCategory.food => Icons.restaurant_outlined,
  PlanCategory.custom => Icons.checklist_rounded,
};

String _statusLabel(PlanStatus status) => switch (status) {
  PlanStatus.active => '进行中',
  PlanStatus.completed => '已完成',
  PlanStatus.archived => '已归档',
};

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _dateRange(DateTime? start, DateTime? end) {
  if (start == null) return '截止 ${_date(end!)}';
  if (end == null) return '开始 ${_date(start)}';
  return '${_date(start)} – ${_date(end)}';
}

String _failureMessage(Object failure) {
  final value = failure.toString();
  if (value.contains('PermissionDenied')) return '没有操作该计划的权限';
  if (value.contains('Unauthorized')) return '请先登录后重试';
  if (value.contains('Validation')) return '计划信息有误，请检查后重试';
  if (value.contains('Network')) return '网络连接失败，请稍后重试';
  return '计划操作失败，请稍后重试';
}

String _readFailureMessage(Object error, String fallback) {
  if (error is StateError) {
    final message = error.message;
    if (const {
      '没有查看该计划的权限',
      '请先登录',
      '网络连接失败，请稍后重试',
      '计划加载失败，请稍后重试',
    }.contains(message)) {
      return message;
    }
  }
  return fallback;
}
