class FoodSpot {
  const FoodSpot({
    required this.id,
    required this.squadId,
    required this.name,
    required this.category,
    required this.averageCost,
    required this.caloriesEstimate,
    required this.addedBy,
    required this.createdAt,
    this.address,
    this.note,
    this.votes = const {},
  });

  final String id;
  final String squadId;
  final String name;
  final String category;
  final double averageCost;
  final int caloriesEstimate;
  final String addedBy;
  final DateTime createdAt;
  final String? address;
  final String? note;
  final Map<String, int> votes;

  int get score => votes.values.fold(0, (sum, vote) => sum + vote);

  FoodSpot copyWith({
    String? id,
    String? squadId,
    String? name,
    String? category,
    double? averageCost,
    int? caloriesEstimate,
    String? addedBy,
    DateTime? createdAt,
    String? address,
    String? note,
    Map<String, int>? votes,
  }) => FoodSpot(
    id: id ?? this.id,
    squadId: squadId ?? this.squadId,
    name: name ?? this.name,
    category: category ?? this.category,
    averageCost: averageCost ?? this.averageCost,
    caloriesEstimate: caloriesEstimate ?? this.caloriesEstimate,
    addedBy: addedBy ?? this.addedBy,
    createdAt: createdAt ?? this.createdAt,
    address: address ?? this.address,
    note: note ?? this.note,
    votes: votes ?? this.votes,
  );
}
