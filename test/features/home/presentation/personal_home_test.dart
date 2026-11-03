import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/app/providers/conversation_customization_providers.dart';
import 'package:squadly/app/providers/personal_home_providers.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/auth/domain/repositories/personal_avatar_repository.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/home/presentation/screens/profile_screen.dart';
import 'package:squadly/features/home/presentation/screens/profile_settings_screen.dart';
import 'package:squadly/features/squad/domain/repositories/squad_profile_repository.dart';
import 'package:squadly/features/squad/domain/squad_avatar_format.dart';

final class _Picker implements SquadAvatarPicker {
  _Picker(this.result);
  final Future<Either<Failure, String?>> result;
  @override
  Future<Either<Failure, String?>> pick() => result;
}

final class _Avatar implements PersonalAvatarRepository {
  final values = <String?>[];
  bool fail = false;
  VoidCallback? onSave;
  @override
  Future<Either<Failure, void>> save(String? avatar) async {
    values.add(avatar);
    if (fail) return left(const Failure.server(message: '头像保存失败，请稍后重试'));
    onSave?.call();
    return right(null);
  }
}

String _avatar() =>
    '$squadAvatarPrefix${base64Encode(File('test/features/squad/fixtures/avatar.png').readAsBytesSync())}';
void main() {
  Future<ProviderContainer> show(
    WidgetTester tester, {
    Widget? screen,
    void Function(ProviderContainer)? configure,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(demoAppStoreProvider.notifier)
        .signInWithEmail(email: 'haiming@example.com', password: 'password1');
    configure?.call(container);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: screen ?? const ProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'home presents identity and showcases without contact or settings controls',
    (tester) async {
      final container = await show(tester);
      final user = container.read(authNotifierProvider).asData!.value!;
      expect(find.text(user.nickname), findsOneWidget);
      expect(find.text(user.email!), findsNothing);
      expect(find.text('退出登录'), findsNothing);
      expect(find.text('清理本机聊天记录'), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byTooltip('设置'), findsOneWidget);
      expect(find.text('成就勋章'), findsOneWidget);
      expect(find.text('小队封面'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-identity')));
      await tester.pumpAndSettle();
      expect(find.text('账号与资料'), findsOneWidget);
      expect(find.text('昵称'), findsOneWidget);
    },
  );
  testWidgets('gear opens nested categories and preserves back navigation', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('展示管理'), findsOneWidget);
    expect(find.text('通知与外观'), findsOneWidget);
    await tester.tap(find.text('展示管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('成就勋章'));
    await tester.pumpAndSettle();
    expect(find.text('勋章收集即将开放'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('展示管理'), findsOneWidget);
    await tester.tap(find.text('小队封面'));
    await tester.pumpAndSettle();
    expect(find.text('封面沿用小队头像与名称'), findsOneWidget);
  });
  testWidgets('media shortcut reaches same hierarchy and does not auto-share', (
    tester,
  ) async {
    var opened = 0;
    await show(
      tester,
      screen: ProfileScreen(onOpenDataWorkshop: () => opened++),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('profile-media')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-media')));
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(find.text('个人媒体资产'), findsOneWidget);
    await tester.tap(find.text('私密素材空间'));
    expect(opened, 1);
  });
  testWidgets('large text and long nickname fit narrow dark profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(demoAppStoreProvider.notifier)
        .signInWithEmail(email: 'haiming@example.com', password: 'password1');
    container
        .read(demoAppStoreProvider.notifier)
        .updateNickname('一位有着很长中文昵称的小队成员');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(body: ProfileScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('personal-home')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('picker result is previewed and cancel does not save', (
    tester,
  ) async {
    final avatar = _Avatar();
    final container = ProviderContainer(
      overrides: [
        personalAvatarAvailableProvider.overrideWithValue(true),
        personalAvatarRepositoryProvider.overrideWithValue(avatar),
        squadAvatarPickerProvider.overrideWithValue(
          _Picker(Future.value(right(_avatar()))),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(demoAppStoreProvider.notifier)
        .signInWithEmail(email: 'haiming@example.com', password: 'password1');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProfileSettingsScreen(section: ProfileSettingsSection.account),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('头像'));
    await tester.pumpAndSettle();
    expect(find.text('预览头像'), findsOneWidget);
    expect(avatar.values, isEmpty);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(avatar.values, isEmpty);
    avatar.fail = true;
    await tester.tap(find.text('头像'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('头像保存失败，请稍后重试'), findsOneWidget);
    expect(find.text('预览头像'), findsOneWidget);
  });
  testWidgets(
    'explicit avatar save updates the same profile and keeps contact',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          personalAvatarAvailableProvider.overrideWithValue(true),
          squadAvatarPickerProvider.overrideWithValue(
            _Picker(Future.value(right(_avatar()))),
          ),
        ],
      );
      addTearDown(container.dispose);
      final before = container
          .read(demoAppStoreProvider.notifier)
          .signInWithEmail(email: 'haiming@example.com', password: 'password1');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProfileSettingsScreen(
              section: ProfileSettingsSection.account,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('头像'));
      await tester.pumpAndSettle();
      expect(
        container.read(authNotifierProvider).asData!.value!.avatarUrl,
        before.avatarUrl,
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final after = container.read(authNotifierProvider).asData!.value!;
      expect(after.avatarUrl, _avatar());
      expect(after.email, before.email);
      expect(after.nickname, before.nickname);
      expect(find.text('预览头像'), findsNothing);
    },
  );

  testWidgets('avatar result after account switch cannot open old preview', (
    tester,
  ) async {
    final pending = Completer<Either<Failure, String?>>();
    final avatar = _Avatar();
    final container = ProviderContainer(
      overrides: [
        personalAvatarAvailableProvider.overrideWithValue(true),
        personalAvatarRepositoryProvider.overrideWithValue(avatar),
        squadAvatarPickerProvider.overrideWithValue(_Picker(pending.future)),
      ],
    );
    addTearDown(container.dispose);
    final store = container.read(demoAppStoreProvider.notifier)
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProfileSettingsScreen(section: ProfileSettingsSection.account),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('头像'));
    await tester.pump();
    store.signInWithEmail(email: 'other@example.com', password: 'password1');
    pending.complete(right(_avatar()));
    await tester.pumpAndSettle();
    expect(find.text('预览头像'), findsNothing);
    expect(avatar.values, isEmpty);
  });
  testWidgets('demo avatar save updates own profile only', (tester) async {
    final container = await show(tester);
    final store = container.read(demoAppStoreProvider.notifier);
    final owner = store.getCurrentUser()!.id;
    final before = {for (final u in store.snapshot.users) u.id: u.avatarUrl};
    expect(
      (await container.read(personalAvatarRepositoryProvider).save(_avatar()))
          .isRight(),
      true,
    );
    for (final user in store.snapshot.users) {
      expect(user.avatarUrl, user.id == owner ? _avatar() : before[user.id]);
    }
  });
}
