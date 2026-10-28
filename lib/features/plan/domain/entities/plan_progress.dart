final class PlanProgress {
  const PlanProgress({required this.completedCount, required this.totalCount});

  final int completedCount;
  final int totalCount;

  double? get fraction => totalCount == 0 ? null : completedCount / totalCount;
}
