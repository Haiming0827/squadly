import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/conversation/data/memory_conversation_outbox.dart';
import 'package:squadly/features/conversation/domain/conversation_outbox.dart';
import 'package:squadly/features/conversation/domain/conversation_repository.dart';
import 'package:squadly/features/conversation/domain/pending_operation.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/conversation/presentation/conversation_controller.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/photos/domain/photo_repository.dart';
import 'package:squadly/features/photos/domain/photo_submission.dart';
import 'package:squadly/features/photos/domain/prepare_squad_photo.dart';

const _squad = '00000000-0000-4000-8000-000000000001';
const _nonce = '00000000-0000-4000-8000-000000000002';
const _parent = '00000000-0000-4000-8000-000000000003';
PhotoDraft _draft({
  String nonce = _nonce,
  String user = 'alice',
  String squad = _squad,
}) => PhotoDraft(
  target: PhotoTarget(
    userId: user,
    squadId: squad,
    squadName: '原小队',
    replyToMessageId: _parent,
  ),
  clientNonce: nonce,
  preparedAt: DateTime.utc(2026, 10, 28),
  image: PhotoImage(
    bytes: File('test/features/photos/fixtures/sanitized.jpg')
        .readAsBytesSync(),
    width: 4,
    height: 3,
    sha256: '9c4ad0cc80a44a2d234c284e474e8feff187fb71a568f3b09d6c5737e49e0cd5',
  ),
);
PublishedPhoto _ack(PhotoDraft d) => PublishedPhoto(
  messageId: d.clientNonce,
  mediaId: '00000000-0000-4000-8000-000000000008',
  squadId: d.target.squadId,
  authorId: d.target.userId,
  clientNonce: d.clientNonce,
  publishedAt: DateTime.utc(2026, 10, 28),
  replyToMessageId: d.target.replyToMessageId,
);

class _Remote implements PhotoRepository {
  final attempts = <PhotoDraft>[];
  final server = <String, PublishedPhoto>{};
  Future<Either<Failure, PublishedPhoto>> Function(PhotoDraft)? handler;
  @override
  Future<Either<Failure, PublishedPhoto>> publish(PhotoDraft d) async {
    attempts.add(d);
    if (handler != null) return handler!(d);
    return right(server.putIfAbsent(d.clientNonce, () => _ack(d)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected photo repository call');
}

class _Timeline implements ConversationRepository {
  _Timeline(this.remote);
  final _Remote remote;
  bool fail = false;
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId, {
    String? planId,
  }) async => fail
      ? left(const Failure.network())
      : right([
          for (final ack in remote.server.values.where(
            (p) => p.squadId == squadId,
          ))
            TimelineEntry(
              id: ack.messageId,
              squadId: ack.squadId,
              authorId: ack.authorId,
              authorName: '队友',
              kind: TimelineEntryKind.photo,
              clientNonce: ack.clientNonce,
              createdAt: ack.publishedAt,
              replyToEntryId: ack.replyToMessageId,
              photo: PhotoAttachment(
                mediaId: ack.mediaId,
                width: 4,
                height: 3,
                byteLength: 42,
                isRevoked: false,
              ),
            ),
        ]);
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) => loadRecent(squadId, planId: planId);
  @override
  Stream<void> watchTimeline(String squadId, {String? planId}) =>
      const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected timeline repository call');
}

class _Outbox implements ConversationOutbox {
  final storage = MemoryConversationOutbox();
  String? block;
  bool removeFails = false;
  bool writeFails = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  Future<void> _wait(String phase) async {
    if (block == phase) {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    }
  }

  @override
  Future<void> put(PendingConversationOperation operation) async {
    if (writeFails) throw StateError('disk unavailable');
    await storage.put(operation);
    await _wait('put');
  }

  @override
  Future<List<PendingConversationOperation>> listFor({
    required String userId,
    required String squadId,
    String? planId,
  }) async {
    await _wait('list');
    return storage.listFor(userId: userId, squadId: squadId, planId: planId);
  }

  @override
  Future<void> remove({
    required String userId,
    required String squadId,
    required String clientNonce,
    String? planId,
  }) async {
    if (removeFails) throw StateError('disk unavailable');
    return storage.remove(
      userId: userId,
      squadId: squadId,
      clientNonce: clientNonce,
      planId: planId,
    );
  }
}

void main() {
  late _Outbox outbox;
  late _Remote remote;
  late _Timeline timeline;
  setUp(() {
    outbox = _Outbox();
    remote = _Remote();
    timeline = _Timeline(remote);
  });
  ConversationController controller({
    String user = 'alice',
    String squad = _squad,
    String? plan,
    PhotoTargetAccess? access,
  }) {
    final c = ConversationController(
      repository: timeline,
      outbox: outbox,
      squadId: squad,
      currentUserId: user,
      planId: plan,
      photos: remote,
      canPublishPhoto: access ?? (_) async => true,
    );
    addTearDown(() {
      if (c.mounted) c.dispose();
    });
    return c;
  }

  test('explicit confirmation persists before upload and removes only after canonical server ack', () async {
    remote.handler = (d) async {
      expect(
        await outbox.listFor(userId: 'alice', squadId: _squad),
        hasLength(1),
      );
      final ack = _ack(d);
      remote.server[d.clientNonce] = ack;
      return right(ack);
    };
    final c = controller();
    expect(await c.publishPhoto(_draft()), isA<PhotoSubmissionSent>());
    await Future<void>.delayed(Duration.zero);
    expect(c.state.pendingCount, 0);
    expect(c.state.entries.single.photo!.byteLength, 42);
    expect(c.state.entries.single.replyToEntryId, _parent);
    expect(await outbox.listFor(userId: 'alice', squadId: _squad), isEmpty);
  });

  test('response lost after commit recovers through the same nonce after controller recreation', () async {
    var lose = true;
    remote.handler = (d) async {
      final ack = remote.server.putIfAbsent(d.clientNonce, () => _ack(d));
      if (lose) {
        lose = false;
        return left(const Failure.network());
      }
      return right(ack);
    };
    final original = controller();
    final d = _draft();
    expect(await original.publishPhoto(d), isA<PhotoSubmissionPending>());
    original.dispose();
    final restored = controller();
    await restored.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(remote.server, hasLength(1));
    expect(remote.attempts, hasLength(2));
    expect(
      sameConfirmedPhoto(remote.attempts.first, remote.attempts.last),
      isTrue,
    );
    expect(restored.state.entries, hasLength(1));
    expect(restored.state.pendingCount, 0);
  });

  test('network and permission failures retain the original photo while local write failure stays unconfirmed', () async {
    final c = controller(access: (_) async => false);
    expect(await c.publishPhoto(_draft()), isA<PhotoSubmissionPending>());
    expect(remote.attempts, isEmpty);
    expect(c.state.pendingCount, 1);
    outbox.writeFails = true;
    final other = _draft(nonce: '00000000-0000-4000-8000-000000000009');
    expect(await c.publishPhoto(other), isA<PhotoSubmissionUnconfirmed>());
    expect(
      (await outbox.listFor(
        userId: 'alice',
        squadId: _squad,
      )).single.clientNonce,
      _nonce,
    );
  });

  test('same nonce with changed parent or time is rejected without replacing durable content', () async {
    remote.handler = (_) async => left(const Failure.network());
    final c = controller();
    final d = _draft();
    await c.publishPhoto(d);
    for (final changed in [
      d.copyWith(target: d.target.copyWith(replyToMessageId: null)),
      d.copyWith(preparedAt: d.preparedAt.add(const Duration(seconds: 1))),
    ]) {
      expect(await c.publishPhoto(changed), isA<PhotoSubmissionRejected>());
    }
    expect(remote.attempts, hasLength(1));
    final saved =
        (await outbox.listFor(userId: 'alice', squadId: _squad)).single
            as PendingPhotoOperation;
    expect(sameConfirmedPhoto(saved.draft, d), isTrue);
  });

  test(
    'different account, squad and plan never replay the original queued photo',
    () async {
      remote.handler = (_) async => left(const Failure.network());
      await controller().publishPhoto(_draft());
      final before = remote.attempts.length;
      await controller(user: 'bob').retryPending();
      await controller(squad: '00000000-0000-4000-8000-000000000004')
          .retryPending();
      await controller(plan: 'private-plan').retryPending();
      expect(remote.attempts, hasLength(before));
      expect(
        await outbox.listFor(userId: 'alice', squadId: _squad),
        hasLength(1),
      );
    },
  );

  for (final phase in ['list', 'put', 'authorization', 'upload']) {
    test(
      'account disposal during $phase cannot resume sending in another account',
      () async {
        if (phase == 'list' || phase == 'put') outbox.block = phase;
        final authorizing = Completer<bool>();
        final authorized = Completer<void>();
        final upload = Completer<Either<Failure, PublishedPhoto>>();
        final uploading = Completer<void>();
        if (phase == 'upload') {
          remote.handler = (_) {
            uploading.complete();
            return upload.future;
          };
        }
        final c = controller(
          access: phase == 'authorization'
              ? (_) {
                  authorized.complete();
                  return authorizing.future;
                }
              : null,
        );
        final sending = c.publishPhoto(_draft());
        if (phase == 'list' || phase == 'put') {
          await outbox.entered.future;
          c.dispose();
          outbox.release.complete();
        }
        if (phase == 'authorization') {
          await authorized.future;
          c.dispose();
          authorizing.complete(true);
        }
        if (phase == 'upload') {
          await uploading.future;
          c.dispose();
          upload.complete(right(_ack(_draft())));
        }
        await sending;
        outbox.block = null;
        await controller(user: 'bob').retryPending();
        expect(remote.attempts, hasLength(phase == 'upload' ? 1 : 0));
        expect(
          await outbox.listFor(userId: 'alice', squadId: _squad),
          hasLength(phase == 'list' ? 0 : 1),
        );
      },
    );
  }

  test(
    'overlapping confirm and retry execute only one in-flight upload',
    () async {
      final gate = Completer<Either<Failure, PublishedPhoto>>();
      final started = Completer<void>();
      remote.handler = (_) {
        started.complete();
        return gate.future;
      };
      final c = controller();
      final first = c.publishPhoto(_draft());
      await started.future;
      expect(await c.publishPhoto(_draft()), isA<PhotoSubmissionUnconfirmed>());
      await c.retryPending();
      expect(remote.attempts, hasLength(1));
      gate.complete(right(_ack(_draft())));
      expect(await first, isA<PhotoSubmissionSent>());
      expect(c.state.pendingCount, 0);
    },
  );

  test(
    'server success remains sent when local cleanup or timeline refresh fails',
    () async {
      outbox.removeFails = true;
      timeline.fail = true;
      final c = controller();
      expect(await c.publishPhoto(_draft()), isA<PhotoSubmissionSent>());
      expect(
        await outbox.listFor(userId: 'alice', squadId: _squad),
        hasLength(1),
      );
      outbox.removeFails = false;
      await c.retryPending();
      expect(remote.server, hasLength(1));
      expect(c.state.pendingCount, 0);
    },
  );

  test('mismatched publication identity retains durable original and never creates local photo entry', () async {
    remote.handler = (d) async => right(_ack(d).copyWith(authorId: 'bob'));
    final c = controller();
    expect(await c.publishPhoto(_draft()), isA<PhotoSubmissionPending>());
    expect(c.state.entries, isEmpty);
    expect(
      await outbox.listFor(userId: 'alice', squadId: _squad),
      hasLength(1),
    );
  });
}
