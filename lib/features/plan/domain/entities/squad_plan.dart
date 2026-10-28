enum PlanCategory { fitness, finance, travel, food, custom }

enum PlanVisibility { squad, private }

enum PlanStatus { active, completed, archived }

/// A plan always belongs to one squad. Visibility controls which members can
/// read it; private plans remain attached to the squad but are owner-only.
final class SquadPlan {
  const SquadPlan({
    required this.id,
    required this.squadId,
    required this.title,
    required this.category,
    required this.visibility,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.startDate,
    this.endDate,
    this.legacySource,
    this.legacyId,
    this.legacyData = const {},
  });

  final String id;
  final String squadId;
  final String title;
  final String? description;
  final PlanCategory category;
  final PlanVisibility visibility;
  final PlanStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? legacySource;
  final String? legacyId;
  final Map<String, dynamic> legacyData;
}

String planCategoryToDb(PlanCategory category) => category.name;

PlanCategory planCategoryFromDb(String value) => PlanCategory.values.firstWhere(
  (category) => category.name == value,
  orElse: () => throw FormatException('Unknown plan category: $value'),
);

String planVisibilityToDb(PlanVisibility visibility) => visibility.name;

PlanVisibility planVisibilityFromDb(String value) =>
    PlanVisibility.values.firstWhere(
      (visibility) => visibility.name == value,
      orElse: () => throw FormatException('Unknown plan visibility: $value'),
    );

String planStatusToDb(PlanStatus status) => status.name;

PlanStatus planStatusFromDb(String value) => PlanStatus.values.firstWhere(
  (status) => status.name == value,
  orElse: () => throw FormatException('Unknown plan status: $value'),
);
