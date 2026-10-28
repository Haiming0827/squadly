import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/plan/domain/entities/plan_progress.dart';

void main() {
  test('returns a fraction when a plan has tasks', () {
    const progress = PlanProgress(completedCount: 1, totalCount: 4);

    expect(progress.fraction, 0.25);
  });

  test('returns no fraction when a plan has no tasks', () {
    const progress = PlanProgress(completedCount: 0, totalCount: 0);

    expect(progress.fraction, isNull);
  });
}
