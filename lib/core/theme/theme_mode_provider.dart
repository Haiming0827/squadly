import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ThemeModeStore {
  Future<String?> read();
  Future<void> write(String mode);
}

final class SharedPreferencesThemeModeStore implements ThemeModeStore {
  SharedPreferencesThemeModeStore({this._preferences});

  static const _key = 'squadly.theme_mode';
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _instance =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<String?> read() async => _instance.getString(_key);

  @override
  Future<void> write(String mode) async => _instance.setString(_key, mode);
}

final themeModeStoreProvider = Provider<ThemeModeStore>(
  (ref) => SharedPreferencesThemeModeStore(),
);

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

final class ThemeModeController extends Notifier<ThemeMode> {
  late ThemeModeStore _store;
  late Future<void> initialized;
  Future<void> _writeQueue = Future<void>.value();
  bool _userSelected = false;

  @override
  ThemeMode build() {
    _store = ref.watch(themeModeStoreProvider);
    initialized = _restore(_store);
    return ThemeMode.system;
  }

  Future<void> select(ThemeMode mode) {
    _userSelected = true;
    state = mode;

    final write = _writeQueue.then((_) => _store.write(mode.name));
    _writeQueue = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return _writeQueue;
  }

  Future<void> _restore(ThemeModeStore store) async {
    try {
      final savedMode = await store.read();
      if (!ref.mounted || _userSelected) return;
      state = switch (savedMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Theme persistence is optional; keep the current mode if unavailable.
    }
  }
}
