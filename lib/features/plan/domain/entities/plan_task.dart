final class PlanTask {
  const PlanTask({
    required this.id,
    required this.planId,
    required this.squadId,
    required this.title,
    required this.isComplete,
    required this.position,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.details,
    this.assignedTo,
    this.dueDate,
    this.completedBy,
    this.completedAt,
  });

  final String id;
  final String planId;
  final String squadId;
  final String title;
  final String? details;
  final String? assignedTo;
  final DateTime? dueDate;
  final bool isComplete;
  final String? completedBy;
  final DateTime? completedAt;
  final int position;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}
