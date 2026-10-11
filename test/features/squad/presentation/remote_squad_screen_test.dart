import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/features/squad/domain/entities/squad.dart';
import 'package:squadly/features/squad/domain/repositories/squad_repository.dart';
import 'package:squadly/features/squad/presentation/providers/squad_provider.dart';
import 'package:squadly/features/squad/presentation/screens/squad_list_screen.dart';

class _SquadBoundary extends Mock implements SquadRepository {}

final _squad = Squad(
  id: 'squad-a',
  name: '周末跑步',
  inviteCode: '',
  createdBy: 'user-a',
  createdAt: DateTime.utc(2026, 10, 8),
);

void main() {
  testWidgets('creating a squad selects the server-created squad', (
    tester,
  ) async {
    final repository = _SquadBoundary();
    when(
      () => repository.createSquad(name: '周末跑步', description: null),
    ).thenAnswer((_) async => Right(_squad));
    final container = ProviderContainer(
      overrides: [
        squadRepositoryProvider.overrideWithValue(repository),
        mySquadsProvider.overrideWith((ref) async => []),
        currentSquadProvider.overrideWith((ref) => const AsyncData(null)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const Scaffold(body: RemoteSquadListScreen()),
        ),
      ),
    );

    await tester.tap(find.text('创建小队'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '周末跑步');
    await tester.tap(find.text('创建').last);
    await tester.pumpAndSettle();

    expect(container.read(selectedSquadIdProvider), 'squad-a');
  });
}
