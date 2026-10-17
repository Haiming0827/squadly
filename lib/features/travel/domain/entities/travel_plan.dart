class TravelPlan {
  const TravelPlan({
    required this.id,
    required this.squadId,
    required this.title,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.createdBy,
    required this.createdAt,
    this.linkedFundId,
    this.notes,
  });

  final String id;
  final String squadId;
  final String title;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final double budget;
  final String? linkedFundId;
  final String createdBy;
  final DateTime createdAt;
  final String? notes;
}
