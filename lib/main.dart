import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/config/backend_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = BackendConfig.fromEnvironment();

  await Supabase.initialize(url: config.url, anonKey: config.anonKey);

  runApp(const ProviderScope(child: SquadlyApp()));
}
