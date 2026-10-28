import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/providers/current_user_provider.dart';
import 'package:squadly/app/providers/squad_context_providers.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/finance/presentation/providers/finance_provider.dart';
import 'package:squadly/features/squad/domain/entities/squad_member.dart';

void main() {
  for (final role in ['captain', 'member']) {
    test('fund capability uses the current membership role: $role', () async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => AsyncData(
              User(
                id: 'user-a',
                nickname: 'Test',
                createdAt: DateTime.utc(2026),
              ),
            ),
          ),
          squadMembersProvider('squad-a').overrideWith(
            (ref) async => [
              SquadMember(
                id: 'membership-a',
                squadId: 'squad-a',
                userId: 'user-a',
                role: role,
                joinedAt: DateTime.utc(2026),
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(canManagePublicFundsProvider('squad-a')), isFalse);
      await container.read(squadMembersProvider('squad-a').future);
      expect(
        container.read(canManagePublicFundsProvider('squad-a')),
        role == 'captain',
      );
    });
  }
  test(
    'signed-out users have no fund capability and do not load memberships',
    () {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => const AsyncData(null)),
          squadMembersProvider('squad-a')
              .overrideWith((ref) => throw StateError('Must not load')),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(canManagePublicFundsProvider('squad-a')), isFalse);
    },
  );
}
