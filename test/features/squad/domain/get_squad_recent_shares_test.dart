import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/conversation/domain/conversation_repository.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/squad/domain/usecases/get_squad_recent_shares.dart';

class _ConversationRepository extends Mock implements ConversationRepository {}

void main() {
  test('returns newest shared cards and excludes ordinary messages', () async {
    final repository = _ConversationRepository();
    when(() => repository.loadRecent('squad-a')).thenAnswer(
      (_) async => right([
        _entry('message-0', DateTime.utc(2026, 10, 18, 9), title: '旧分享'),
        _entry('message-1', DateTime.utc(2026, 10, 18, 10), title: '晨跑'),
        _textEntry('text-1', DateTime.utc(2026, 10, 18, 11)),
        _entry('message-2', DateTime.utc(2026, 10, 18, 12), title: '周末徒步'),
        _entry('message-3', DateTime.utc(2026, 10, 18, 13), title: '骑行'),
      ]),
    );

    final result = await GetSquadRecentShares(repository)(squadId: 'squad-a');

    expect(result.getOrElse((_) => []).map((share) => share.messageId), [
      'message-3',
      'message-2',
      'message-1',
    ]);
    expect(result.getOrElse((_) => []).map((share) => share.title), [
      '骑行',
      '周末徒步',
      '晨跑',
    ]);
  });

  test('preserves repository failure', () async {
    final repository = _ConversationRepository();
    when(
      () => repository.loadRecent('squad-a'),
    ).thenAnswer((_) async => left(const Failure.network(message: 'offline')));

    final result = await GetSquadRecentShares(repository)(squadId: 'squad-a');

    expect(result.isLeft(), isTrue);
  });

  test('rejects an invalid share query limit', () async {
    final repository = _ConversationRepository();

    final result = await GetSquadRecentShares(repository)(
      squadId: 'squad-a',
      limit: 21,
    );

    expect(result.isLeft(), isTrue);
    verifyNever(() => repository.loadRecent(any()));
  });
}

TimelineEntry _entry(String id, DateTime createdAt, {required String title}) =>
    TimelineEntry(
      id: id,
      squadId: 'squad-a',
      authorId: 'user-a',
      authorName: '阿青',
      kind: TimelineEntryKind.card,
      cardId: 'card-$id',
      cardSnapshot: CardSnapshot(
        kind: CardKind.activity,
        payload: {'title': title},
      ),
      clientNonce: 'nonce-$id',
      createdAt: createdAt,
    );

TimelineEntry _textEntry(String id, DateTime createdAt) => TimelineEntry(
  id: id,
  squadId: 'squad-a',
  authorId: 'user-a',
  authorName: '阿青',
  kind: TimelineEntryKind.text,
  text: '今天也要加油',
  clientNonce: 'nonce-$id',
  createdAt: createdAt,
);
