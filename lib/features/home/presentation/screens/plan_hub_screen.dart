import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/cloudbase_client_provider.dart';
import '../../../plan/domain/entities/squad_plan.dart';
import '../../../plan/presentation/screens/plan_home_screen.dart';

class PlanHubScreen extends ConsumerWidget {
  const PlanHubScreen({
    required this.onOpenSquads,
    this.onOpenPlanDiscussion,
    super.key,
  });

  final VoidCallback onOpenSquads;
  final ValueChanged<SquadPlan>? onOpenPlanDiscussion;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PlanHomeScreen(
    isDemo: ref.watch(useDemoBackendProvider),
    onOpenScenario: (category) => context.pushNamed(_scenarioRoute(category)),
    onOpenPlanDiscussion: onOpenPlanDiscussion,
    onOpenSquads: onOpenSquads,
  );

  String _scenarioRoute(PlanCategory category) => switch (category) {
    PlanCategory.fitness => 'fitness',
    PlanCategory.finance => 'finance',
    PlanCategory.travel => 'travel',
    PlanCategory.food => 'food',
    PlanCategory.custom => 'home',
  };
}
