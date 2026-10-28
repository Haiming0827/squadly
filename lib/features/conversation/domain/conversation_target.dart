/// A general Squad conversation or the independent discussion for one plan.
/// Plan discussions retain Squad ownership and authorization context.
final class ConversationTarget {
  const ConversationTarget({required this.squadId, this.planId});

  final String squadId;
  final String? planId;

  bool get isPlanDiscussion => planId != null;

  @override
  bool operator ==(Object other) =>
      other is ConversationTarget &&
      other.squadId == squadId &&
      other.planId == planId;

  @override
  int get hashCode => Object.hash(squadId, planId);
}
