import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

/// Read-only identity context for app and feature composition.
///
/// Feature providers should depend on this app-level binding instead of
/// importing the auth presentation notifier directly. Auth mutations stay in
/// the auth feature.
final currentUserProvider = Provider((ref) => ref.watch(authNotifierProvider));
