import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/app/providers/conversation_runtime_providers.dart';
import 'package:squadly/app/providers/current_user_provider.dart';
import 'package:squadly/app/providers/domain_repository_providers.dart';
import 'package:squadly/app/providers/photo_providers.dart';
import 'package:squadly/app/providers/photo_safety_providers.dart';
import 'package:squadly/app/providers/photo_submission_provider.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/conversation/data/memory_conversation_outbox.dart';
import 'package:squadly/features/conversation/domain/conversation_repository.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/photos/domain/photo_repository.dart';
import 'package:squadly/features/photos/domain/photo_safety_repository.dart';
import 'package:squadly/features/photos/domain/photo_submission.dart';
import 'package:squadly/features/secure_route/domain/route_models.dart';

const target = PhotoTarget(
  userId: 'alice',
  squadId: '00000000-0000-4000-8000-000000000001',
  squadName: '周末小队',
);
const attachment = PhotoAttachment(
  mediaId: 'media',
  width: 4,
  height: 3,
  byteLength: 600,
  isRevoked: false,
);
PhotoImage testImage() => PhotoImage(
  bytes: File('test/features/photos/fixtures/sanitized.jpg').readAsBytesSync(),
  width: 4,
  height: 3,
  sha256: '9c4ad0cc80a44a2d234c284e474e8feff187fb71a568f3b09d6c5737e49e0cd5',
);
final testUser = StateProvider<String>((ref) => 'alice');
final testReady = StateProvider<bool>((ref) => true);
final testAvailable = StateProvider<bool>((ref) => true);

class TestPhotoSource implements PhotoSourceGateway {
  final calls = <PhotoSource>[];
  Future<Either<Failure, PhotoImage?>> Function(PhotoSource)? handler;
  @override
  Future<Either<Failure, PhotoImage?>> pick(PhotoSource source) async {
    calls.add(source);
    return handler == null ? right(testImage()) : handler!(source);
  }
}

class TestPhotoRepository implements PhotoRepository, PhotoSafetyRepository {
  final hides = <String>[];
  final reports = <PhotoReportReason>[];
  Future<Either<Failure, void>> Function()? onSafety;
  @override
  Future<Either<Failure, void>> hide({
    required String squadId,
    required String messageId,
  }) async {
    hides.add(messageId);
    return onSafety == null ? right(null) : onSafety!();
  }

  @override
  Future<Either<Failure, void>> report({
    required String squadId,
    required String messageId,
    required PhotoReportReason reason,
  }) async {
    reports.add(reason);
    return onSafety == null ? right(null) : onSafety!();
  }

  final drafts = <PhotoDraft>[];
  final loads = <({String squadId, String messageId})>[];
  final revokes = <({String squadId, String messageId})>[];
  Future<Either<Failure, PublishedPhoto>> Function(PhotoDraft)? onPublish;
  Future<Either<Failure, PhotoImage>> Function()? onLoad;
  Future<Either<Failure, void>> Function()? onRevoke;
  @override
  Future<Either<Failure, PublishedPhoto>> publish(PhotoDraft draft) async {
    drafts.add(draft);
    if (onPublish != null) return onPublish!(draft);
    return right(
      PublishedPhoto(
        messageId: 'message',
        mediaId: 'media',
        squadId: draft.target.squadId,
        authorId: draft.target.userId,
        clientNonce: draft.clientNonce,
        publishedAt: DateTime.utc(2026),
        replyToMessageId: draft.target.replyToMessageId,
      ),
    );
  }

  @override
  Future<Either<Failure, PhotoImage>> load({
    required String squadId,
    required String messageId,
  }) async {
    loads.add((squadId: squadId, messageId: messageId));
    return onLoad == null ? right(testImage()) : onLoad!();
  }

  @override
  Future<Either<Failure, void>> revoke({
    required String squadId,
    required String messageId,
  }) async {
    revokes.add((squadId: squadId, messageId: messageId));
    return onRevoke == null ? right(null) : onRevoke!();
  }
}

class PhotoHarness {
  final source = TestPhotoSource();
  final repository = TestPhotoRepository();
  final outbox = MemoryConversationOutbox();
  ConfirmPhoto? submit;
  final accesses = <PhotoTarget>[];
  bool allowed = true;
  late ProviderContainer container;
  bool? routeResult;

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    bool route = false,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => AsyncData(
              User(
                id: ref.watch(testUser),
                nickname: '队友',
                createdAt: DateTime.utc(2026),
              ),
            ),
          ),
          photoSessionReadyProvider.overrideWith((ref) => ref.watch(testReady)),
          photoSendingAvailableProvider.overrideWith(
            (ref) => ref.watch(testAvailable),
          ),
          photoRepositoryProvider.overrideWithValue(repository),
          photoSafetyRepositoryProvider.overrideWithValue(repository),
          if (submit != null)
            photoSubmissionProvider.overrideWith((ref, target) => submit!),
          conversationRepositoryProvider.overrideWithValue(_Timeline()),
          conversationOutboxProvider.overrideWithValue(outbox),
          photoSourceProvider.overrideWithValue(source),
          photoTargetAccessProvider.overrideWithValue((t) async {
            accesses.add(t);
            return allowed;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return route
                  ? Scaffold(
                      body: TextButton(
                        onPressed: () async {
                          routeResult = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => child),
                          );
                        },
                        child: const Text('打开照片'),
                      ),
                    )
                  : Scaffold(body: child);
            },
          ),
        ),
      ),
    );
    if (route) {
      await tester.tap(find.text('打开照片'));
    }
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }
}

class _Timeline implements ConversationRepository {
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId, {
    String? planId,
  }) async => right([]);
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadBefore(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) async => right([]);
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) async => right([]);
  @override
  Stream<void> watchTimeline(String squadId, {String? planId}) =>
      const Stream.empty();
  @override
  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
    String? planId,
  }) async => left(const Failure.server(message: 'Not used'));
  @override
  Future<Either<Failure, TimelineEntry>> publishCard({
    required String squadId,
    required String cardId,
    required CardSnapshot snapshot,
    required String clientNonce,
    EncryptedRouteBundle? encryptedRoute,
  }) async => left(const Failure.server(message: 'Not used'));
  @override
  Future<Either<Failure, Map<String, String>>> loadMessageTexts({
    required String squadId,
    required List<String> messageIds,
  }) async => right({});
}
