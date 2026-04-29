import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_client_provider.g.dart';

/// Supabase 客户端 Provider（全局单例）
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) {
  return Supabase.instance.client;
}

/// 当前认证用户 Provider
@riverpod
User? currentUser(Ref ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser;
}

/// 认证状态流 Provider
@riverpod
Stream<AuthState> authStateChanges(Ref ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
}
