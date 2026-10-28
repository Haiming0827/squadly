import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squadly/app/providers/conversation_runtime_providers.dart';
import 'package:squadly/core/config/cloudbase_config.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/features/conversation/domain/conversation_repository.dart';
import 'package:squadly/features/conversation/domain/pending_operation.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/conversation/presentation/conversation_controller.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/photos/domain/photo_repository.dart';
import 'package:squadly/features/photos/domain/photo_submission.dart';

import 'photo_fixture.dart';

const _user = 'photo-outbox-native-fixture-a';
const _other = 'photo-outbox-native-fixture-b';
const _squad = '00000000-0000-4000-8000-000000000011';
const _nonce = '00000000-0000-4000-8000-000000000012';
const _parent = '00000000-0000-4000-8000-000000000013';
const _otherNonce = '00000000-0000-4000-8000-000000000014';
PhotoDraft _draft() => PhotoDraft(
  target: const PhotoTarget(
    userId: _user,
    squadId: _squad,
    squadName: '原生待发验收',
    replyToMessageId: _parent,
  ),
  image: syntheticPhotoImage(),
  clientNonce: _nonce,
  preparedAt: DateTime.utc(2026, 10, 28),
);

class _Remote implements PhotoRepository {
  bool offline = false;
  final attempts = <PhotoDraft>[];
  @override
  Future<Either<Failure, PublishedPhoto>> publish(PhotoDraft draft) async {
    attempts.add(draft);
    return offline
        ? left(const Failure.network(message: 'Synthetic offline transport'))
        : right(
            PublishedPhoto(
              messageId: _nonce,
              mediaId: '00000000-0000-4000-8000-000000000015',
              squadId: _squad,
              authorId: _user,
              clientNonce: _nonce,
              publishedAt: DateTime.utc(2026, 10, 28),
              replyToMessageId: _parent,
            ),
          );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected native test media operation');
}

class _Timeline implements ConversationRepository {
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId, {
    String? planId,
  }) async => right([]);
  @override
  Stream<void> watchTimeline(String squadId, {String? planId}) =>
      const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected native test timeline operation');
}

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw const SocketException(
        'Network disabled for synthetic native outbox acceptance',
      );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_PHOTO_OUTBOX_NATIVE');
  const phase = String.fromEnvironment('PHOTO_OUTBOX_PHASE');
  testWidgets('iOS encrypted photo queue across processes: $phase', (
    tester,
  ) async {
    expect(['seed', 'read'], contains(phase));
    final previous = HttpOverrides.current;
    HttpOverrides.global = _NoNetwork();
    final container = ProviderContainer(
      overrides: [
        cloudBaseConfigProvider.overrideWithValue(
          CloudBaseConfig.fromValues(
            useDemo: 'false',
            environmentId: 'squadly-photo-outbox-native-fixture',
            region: 'ap-shanghai',
            publishableKey: 'synthetic-public-key-not-a-real-credential',
          ),
        ),
      ],
    );
    final remote = _Remote()..offline = phase == 'seed';
    ConversationController? controller;
    try {
      // This is the real app composition: native SQLite path/isolate and iOS
      // Keychain vault. Only the transport and actors are synthetic.
      final outbox = container.read(conversationOutboxProvider);
      final prefs = await SharedPreferences.getInstance();
      if (phase == 'seed') {
        await outbox.remove(
          userId: _user,
          squadId: _squad,
          clientNonce: _nonce,
        );
        await outbox.remove(
          userId: _other,
          squadId: _squad,
          clientNonce: _otherNonce,
        );
        controller = ConversationController(
          repository: _Timeline(),
          outbox: outbox,
          squadId: _squad,
          currentUserId: _user,
          photos: remote,
          canPublishPhoto: (_) async => true,
        );
        expect(
          await controller.publishPhoto(_draft()),
          isA<PhotoSubmissionPending>(),
        );
        final saved =
            (await outbox.listFor(userId: _user, squadId: _squad)).single
                as PendingPhotoOperation;
        expect(sameConfirmedPhoto(saved.draft, _draft()), isTrue);
        await prefs.setInt('photo_outbox_seed_process', pid);
        await prefs.setBool('photo_outbox_seed_verified', true);
      } else {
        expect(prefs.getBool('photo_outbox_seed_verified'), isTrue);
        expect(
          prefs.getInt('photo_outbox_seed_process'),
          isNot(pid),
          reason: 'Read must run in another app process',
        );
        final saved =
            (await outbox.listFor(userId: _user, squadId: _squad)).single
                as PendingPhotoOperation;
        expect(sameConfirmedPhoto(saved.draft, _draft()), isTrue);
        final otherController = ConversationController(
          repository: _Timeline(),
          outbox: outbox,
          squadId: _squad,
          currentUserId: _other,
          photos: remote,
          canPublishPhoto: (_) async => true,
        );
        try {
          await otherController.retryPending();
          expect(remote.attempts, isEmpty);
        } finally {
          otherController.dispose();
        }
        await outbox.put(
          saved.copyWith(userId: _other, clientNonce: _otherNonce),
        );
        controller = ConversationController(
          repository: _Timeline(),
          outbox: outbox,
          squadId: _squad,
          currentUserId: _user,
          photos: remote,
          canPublishPhoto: (_) async => true,
        );
        await controller.initialize();
        expect(remote.attempts, hasLength(1));
        expect(sameConfirmedPhoto(remote.attempts.single, _draft()), isTrue);
        expect(await outbox.listFor(userId: _user, squadId: _squad), isEmpty);
        expect(
          await outbox.listFor(userId: _other, squadId: _squad),
          hasLength(1),
        );
        await outbox.remove(
          userId: _other,
          squadId: _squad,
          clientNonce: _otherNonce,
        );
        await prefs.remove('photo_outbox_seed_process');
        await prefs.remove('photo_outbox_seed_verified');
      }
    } finally {
      controller?.dispose();
      container.dispose();
      HttpOverrides.global = previous;
    }
  }, skip: !enabled || !Platform.isIOS);
}
