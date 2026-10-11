import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../../core/config/backend_config.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/conversation_outbox_database.dart';
import '../data/drift_conversation_outbox.dart';
import '../data/memory_conversation_outbox.dart';
import '../data/outbox_key_vault.dart';
import '../data/supabase_conversation_repository.dart';
import '../domain/conversation_outbox.dart';
import '../domain/conversation_repository.dart';
import '../domain/timeline_entry.dart';
import 'conversation_controller.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return SupabaseConversationRepository(ref.watch(supabaseClientProvider));
});

final conversationOutboxProvider = Provider<ConversationOutbox>((ref) {
  if (BackendConfig.fromEnvironment().useDemo) {
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
    .family<ConversationController, ConversationState, String>((ref, squadId) {
      final userId = ref.watch(authNotifierProvider).valueOrNull?.id ?? '';
      final controller = ConversationController(
        repository: ref.watch(conversationRepositoryProvider),
        outbox: ref.watch(conversationOutboxProvider),
        squadId: squadId,
        currentUserId: userId,
      );
      unawaited(controller.initialize());
      return controller;
    });
