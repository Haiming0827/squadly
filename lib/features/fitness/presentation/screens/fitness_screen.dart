import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../shared/widgets/app_section.dart';

class FitnessScreen extends ConsumerWidget {
  const FitnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoAppStoreProvider);
    final store = ref.read(demoAppStoreProvider.notifier);
    final squad = state.currentSquad;
    if (squad == null) {
      return const EmptyState(
        icon: Icons.fitness_center_outlined,
        title: '先加入小队',
      );
    }

    final today = DateTime.now();
    final tasks = state.tasksFor(squad.id);
    final checkIns = state.todayCheckInsFor(squad.id, today);
    final completedTaskIds = checkIns
        .where((item) => item.userId == state.currentUser?.id)
        .map((item) => item.taskId)
        .toSet();
    final calories = state.currentUser == null
        ? 0
        : state.caloriesBurnedBy(state.currentUser!.id, today);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AppSection(
          title: '今日概览',
          child: Row(
            children: [
              MetricTile(
                label: '任务',
                value: '${completedTaskIds.length}/${tasks.length}',
                icon: Icons.task_alt_rounded,
              ),
              const SizedBox(width: 10),
              MetricTile(
                label: '消耗',
                value: '$calories kcal',
                icon: Icons.local_fire_department_outlined,
              ),
            ],
          ),
        ),
        AppSection(
          title: '每日打卡',
          trailing: IconButton(
            tooltip: '新增任务',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showTaskDialog(context, store, squad.id),
          ),
          child: tasks.isEmpty
              ? const EmptyState(icon: Icons.checklist_rounded, title: '暂无打卡任务')
              : Column(
                  children: [
                    for (final task in tasks)
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: Icon(
                            completedTaskIds.contains(task.id)
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: completedTaskIds.contains(task.id)
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(task.title),
                          subtitle: Text(
                            '${_taskTypeLabel(task.taskType)}'
                            '${task.targetValue == null ? '' : ' · ${_formatNumber(task.targetValue!)} ${task.targetUnit ?? ''}'}',
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () => _showCheckInDialog(
                              context,
                              store,
                              squad.id,
                              task.id,
                              task.targetValue,
                            ),
                            child: const Text('打卡'),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        AppSection(
          title: '健康记录',
          trailing: IconButton(
            tooltip: '记录健康数据',
            icon: const Icon(Icons.monitor_heart_outlined),
            onPressed: () => _showHealthDialog(context, store, squad.id),
          ),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (final snapshot in state.healthSnapshots.where(
                  (s) => s.squadId == squad.id,
                ))
                  ListTile(
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: Text(
                      '${snapshot.workoutMinutes ?? 0} 分钟 · '
                      '${snapshot.caloriesBurned ?? 0} kcal',
                    ),
                    subtitle: Text(
                      '${snapshot.recordedDate.year}-${snapshot.recordedDate.month.toString().padLeft(2, '0')}-${snapshot.recordedDate.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: snapshot.weight == null
                        ? null
                        : Text('${snapshot.weight!.toStringAsFixed(1)} kg'),
                  ),
              ],
            ),
          ),
        ),
        AppSection(
          title: '训练计划',
          child: Column(
            children: [
              for (final plan in state.workoutPlans.where(
                (item) => item.squadId == squad.id,
              ))
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(plan.name),
                    subtitle: Text(
                      plan.description ?? _planTypeLabel(plan.planType),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showTaskDialog(
    BuildContext context,
    DemoAppStore store,
    String squadId,
  ) async {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '15');
    var taskType = 'stretch';
    var unit = 'minutes';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新增打卡任务'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '任务名称'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: taskType,
                decoration: const InputDecoration(labelText: '类型'),
                items: const [
                  DropdownMenuItem(value: 'stretch', child: Text('拉伸')),
                  DropdownMenuItem(value: 'cardio', child: Text('有氧')),
                  DropdownMenuItem(value: 'night_run', child: Text('夜跑')),
                  DropdownMenuItem(value: 'home_training', child: Text('居家训练')),
                ],
                onChanged: (value) => setState(() {
                  taskType = value ?? taskType;
                  unit = taskType == 'night_run' ? 'km' : 'minutes';
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                decoration: InputDecoration(labelText: '目标（$unit）'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  _showSnack(context, '请输入任务名称');
                  return;
                }
                store.createDailyTask(
                  squadId: squadId,
                  title: titleController.text,
                  taskType: taskType,
                  targetValue: double.tryParse(targetController.text),
                  targetUnit: unit,
                );
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    targetController.dispose();
  }

  Future<void> _showCheckInDialog(
    BuildContext context,
    DemoAppStore store,
    String squadId,
    String taskId,
    double? defaultValue,
  ) async {
    final valueController = TextEditingController(
      text: defaultValue?.toStringAsFixed(defaultValue % 1 == 0 ? 0 : 1) ?? '',
    );
    final noteController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('今日打卡'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              decoration: const InputDecoration(labelText: '完成值'),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: '备注'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              store.checkInTask(
                taskId: taskId,
                squadId: squadId,
                value: double.tryParse(valueController.text),
                note: noteController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('完成'),
          ),
        ],
      ),
    );
    valueController.dispose();
    noteController.dispose();
  }

  Future<void> _showHealthDialog(
    BuildContext context,
    DemoAppStore store,
    String squadId,
  ) async {
    final weightController = TextEditingController();
    final minutesController = TextEditingController(text: '30');
    final caloriesController = TextEditingController(text: '280');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记录健康数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              decoration: const InputDecoration(labelText: '体重 kg'),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minutesController,
              decoration: const InputDecoration(labelText: '运动分钟'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: caloriesController,
              decoration: const InputDecoration(labelText: '消耗 kcal'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              store.recordHealthSnapshot(
                squadId: squadId,
                weight: double.tryParse(weightController.text),
                workoutMinutes: int.tryParse(minutesController.text),
                caloriesBurned: int.tryParse(caloriesController.text),
              );
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    weightController.dispose();
    minutesController.dispose();
    caloriesController.dispose();
  }
}

String _taskTypeLabel(String value) {
  return switch (value) {
    'stretch' => '拉伸',
    'cardio' => '有氧',
    'night_run' => '夜跑',
    'home_training' => '居家训练',
    _ => '自定义',
  };
}

String _planTypeLabel(String value) {
  return switch (value) {
    'muscle_gain' => '增肌',
    'fat_loss' => '减脂',
    'body_shaping' => '塑形',
    _ => '自定义',
  };
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
