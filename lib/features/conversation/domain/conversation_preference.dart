import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/error/failures.dart';

part 'conversation_preference.freezed.dart';

@freezed
abstract class ConversationPreference with _$ConversationPreference {
  const ConversationPreference._();
  const factory ConversationPreference({
    required String squadId,
    @Default('') String remark,
    DateTime? pinnedAt,
    DateTime? lastOpenedAt,
    @Default(0) int recentOpenCount,
  }) = _ConversationPreference;
  bool get isPinned => pinnedAt != null;
  String displayName(String sharedName) => remark.isEmpty ? sharedName : remark;
}

/// Private settings for the current account's active Squad memberships.
abstract interface class ConversationCustomizationRepository {
  Future<Either<Failure, List<ConversationPreference>>> load();
  Future<Either<Failure, void>> save({
    required String squadId,
    required String remark,
    required bool pinned,
  });
  Future<Either<Failure, void>> recordOpen(String squadId);
}

/// Negative means a precedes b. Only active memberships enter this ordering.
int compareFrequentConversations(
  ConversationPreference a,
  ConversationPreference b,
) {
  if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
  if (a.isPinned) {
    final pinnedOrder = b.pinnedAt!.compareTo(a.pinnedAt!);
    if (pinnedOrder != 0) return pinnedOrder;
  }
  final countOrder = b.recentOpenCount.compareTo(a.recentOpenCount);
  if (countOrder != 0) return countOrder;
  final timeOrder = (b.lastOpenedAt ?? DateTime(1970)).compareTo(
    a.lastOpenedAt ?? DateTime(1970),
  );
  return timeOrder != 0 ? timeOrder : a.squadId.compareTo(b.squadId);
}
