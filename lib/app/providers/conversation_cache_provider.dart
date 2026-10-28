import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../core/network/cloudbase_client_provider.dart';
import '../../features/conversation/data/conversation_cache_database.dart';
import '../../features/conversation/data/drift_conversation_cache.dart';
import '../../features/conversation/data/outbox_key_vault.dart';
import '../../features/conversation/domain/conversation_cache.dart';

/// Does not depend on auth: sign-out can clear it without a provider cycle.
final conversationCacheProvider = Provider<ConversationCache?>((ref) {
  if (ref.watch(cloudBaseConfigProvider).useDemo) return null;
  final database = ConversationCacheDatabase(
    LazyDatabase(() async {
      final support = await getApplicationSupportDirectory();
      final temporaryPath = (await getTemporaryDirectory()).path;
      return NativeDatabase.createInBackground(
        File(path.join(support.path, 'squadly-conversation-cache.sqlite')),
        isolateSetup: () {
          sqlite.sqlite3.tempDirectory = temporaryPath;
        },
      );
    }),
  );
  final cache = DriftConversationCache(
    database: database,
    vault: FlutterOutboxKeyVault(),
  );
  ref.onDispose(() => unawaited(cache.close()));
  return cache;
});
