import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/theme/theme_mode_provider.dart';

void main() {
  test('restores a saved appearance preference', () async {
    final store = _MemoryThemeModeStore(savedMode: 'dark');
    final container = ProviderContainer(
      overrides: [themeModeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
    await container.read(themeModeProvider.notifier).initialized;

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('persists a user-selected appearance preference', () async {
    final store = _MemoryThemeModeStore();
    final container = ProviderContainer(
      overrides: [themeModeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final controller = container.read(themeModeProvider.notifier);
    await controller.initialized;

    await controller.select(ThemeMode.light);

    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(store.savedMode, 'light');
  });

  test('a pending restore cannot replace a newer user selection', () async {
    final store = _MemoryThemeModeStore(readCompleter: Completer<String?>());
    final container = ProviderContainer(
      overrides: [themeModeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final controller = container.read(themeModeProvider.notifier);

    final selection = controller.select(ThemeMode.dark);
    store.readCompleter!.complete('light');
    await controller.initialized;
    await selection;

    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(store.savedMode, 'dark');
  });
}

final class _MemoryThemeModeStore implements ThemeModeStore {
  _MemoryThemeModeStore({this.savedMode, this.readCompleter});

  String? savedMode;
  final Completer<String?>? readCompleter;

  @override
  Future<String?> read() async =>
      readCompleter == null ? savedMode : readCompleter!.future;

  @override
  Future<void> write(String mode) async {
    savedMode = mode;
  }
}
