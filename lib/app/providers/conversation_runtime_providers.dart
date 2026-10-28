import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../core/network/cloudbase_client_provider.dart';
import '../../features/conversation/data/conversation_outbox_database.dart';
import '../../features/conversation/data/drift_conversation_outbox.dart';
import '../../features/conversation/data/memory_conversation_outbox.dart';
import '../../features/conversation/data/outbox_key_vault.dart';
import '../../features/conversation/domain/conversation_outbox.dart';
import '../../features/conversation/domain/conversation_target.dart';
import '../../features/conversation/domain/timeline_entry.dart';
import '../../features/conversation/presentation/conversation_controller.dart';
import 'current_user_provider.dart';
import 'domain_repository_providers.dart';
import 'photo_providers.dart';

/// Application composition for the conversation's local runtime and
/// controller. Feature surfaces use the domain-facing repository binding.
final conversationOutboxProvider = Provider<ConversationOutbox>((ref) {
  if (ref.watch(cloudBaseConfigProvider).useDemo) {
    return MemoryConversationOutbox();
  }
  final database = ConversationOutboxDatabase(
    LazyDatabase(() async {
      final support = await getApplicationSupportDirectory();
      final temporary = await getTemporaryDirectory();
      final temporaryPath = temporary.path;
      return NativeDatabase.createInBackground(
        File(path.join(support.path, 'squadly-outbox.sqlite')),
        isolateSetup: () {
          sqlite.sqlite3.tempDirectory = temporaryPath;
        },
      );
    }),
  );
  ref.onDispose(() => unawaited(database.close()));
  return DriftConversationOutbox(
    database: database,
    vault: FlutterOutboxKeyVault(),
  );
});

final conversationControllerProvider = StateNotifierProvider.autoDispose
    .family<ConversationController, ConversationState, ConversationTarget>((
      ref,
      target,
    ) {
      final userId = ref.watch(currentUserProvider).value?.id ?? '';
      final controller = ConversationController(
        repository: ref.watch(conversationRepositoryProvider),
        outbox: ref.watch(conversationOutboxProvider),
        squadId: target.squadId,
        planId: target.planId,
        currentUserId: userId,
        photos: ref.watch(photoRepositoryProvider),
        canPublishPhoto: (target) =>
            ref.read(photoTargetAccessProvider)(target),
        onlineEvents: ref.watch(cloudBaseConfigProvider).useDemo
            ? const Stream<bool>.empty()
            : Connectivity().onConnectivityChanged.map(
                (results) =>
                    results.any((result) => result != ConnectivityResult.none),
              ),
      );
      unawaited(controller.initialize());
      return controller;
    });
