import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:squadly/app/app.dart';
import 'package:squadly/core/config/backend_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const useDemoBackend = bool.fromEnvironment(
    'USE_DEMO_BACKEND',
    defaultValue: true,
  );

  testWidgets('login and navigate primary tabs', (tester) async {
    final backend = BackendConfig.fromEnvironment();
    if (!useDemoBackend) {
      await Supabase.initialize(url: backend.url, anonKey: backend.anonKey);
    }
    await tester.pumpWidget(const ProviderScope(child: SquadlyApp()));
    await tester.pumpAndSettle();

    if (useDemoBackend) {
      await tester.enterText(
        find.byType(EditableText).at(0),
        'haiming@example.com',
      );
      await tester.enterText(find.byType(EditableText).at(1), 'password1');
      await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
      await tester.pumpAndSettle();

      for (final tab in ['数据', '计划', '我的', '小队']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(find.text(tab), findsWidgets);
      }

      await tester.tap(find.text('计划').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('健身'));
      await tester.pumpAndSettle();
      expect(find.text('健身'), findsWidgets);
      return;
    }

    const email = String.fromEnvironment('SMOKE_TEST_EMAIL');
    const password = String.fromEnvironment('SMOKE_TEST_PASSWORD');
    const secondEmail = String.fromEnvironment('SMOKE_TEST_SECOND_EMAIL');
    const secondPassword = String.fromEnvironment('SMOKE_TEST_SECOND_PASSWORD');
    if (email.isEmpty || password.isEmpty) {
      throw StateError(
        'Real-mode smoke tests need generated local credentials',
      );
    }
    await _register(tester, email, password, '联调队长');
    expect(find.textContaining('本地演示'), findsNothing);

    if (secondEmail.isEmpty || secondPassword.isEmpty) {
      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      expect(find.text('账号与联系方式'), findsOneWidget);
      expect(tester.takeException(), isNull);
      return;
    }

    // Exercise the real authenticated UI and the server's invitation/RLS
    // contract with two independent local accounts on one simulator.
    await tester.tap(find.text('小队').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '创建小队'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '小队名称'), '双账号联调小队');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(find.text('双账号联调小队'), findsWidgets);

    final issueButton = find.widgetWithText(FilledButton, '生成邀请码和邀请链接');
    await tester.ensureVisible(issueButton);
    await tester.tap(issueButton);
    await tester.pumpAndSettle();
    final invitationText = tester
        .widget<SelectableText>(find.byType(SelectableText).first)
        .data!;
    final invitationCode = invitationText.replaceFirst('邀请码：', '').trim();
    expect(invitationCode, isNotEmpty);

    await _signOut(tester);
    await _register(tester, secondEmail, secondPassword, '联调队员');
    await tester.tap(find.text('小队').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '输入邀请码或邀请链接'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '邀请码或邀请链接'),
      invitationCode,
    );
    await tester.tap(find.widgetWithText(FilledButton, '加入'));
    await tester.pumpAndSettle();
    expect(find.text('已加入小队'), findsOneWidget);
    expect(find.text('双账号联调小队'), findsWidgets);

    await tester.tap(find.text('会话').last);
    await tester.pumpAndSettle();
    const message = '本地双账号联调消息';
    final secondClient = Supabase.instance.client;
    final secondUser = secondClient.auth.currentUser!;
    final membership = await secondClient
        .from('squad_members')
        .select('squad_id')
        .eq('user_id', secondUser.id)
        .single();
    final squadId = membership['squad_id'] as String;
    await tester.enterText(find.byType(TextField).last, message);
    final sendButton = find.byTooltip('发送消息');
    final sendAction = find.ancestor(
      of: sendButton,
      matching: find.byType(IconButton),
    );
    tester.widget<IconButton>(sendAction).onPressed!.call();
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);

    await _invokeIconAction(tester, '生成卡片');
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '群聊内容卡'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    final sourceMessage = find.widgetWithText(CheckboxListTile, message);
    await tester.ensureVisible(sourceMessage);
    tester.widget<CheckboxListTile>(sourceMessage).onChanged!(true);
    await tester.pumpAndSettle();
    await _publishFromComposer(tester);
    await tester.pumpAndSettle();

    final activityCard = await secondClient.rpc(
      'publish_card_message',
      params: {
        'p_squad_id': squadId,
        'p_kind': 'activity',
        'p_snapshot': {
          'activity_type': 'run',
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'distance_m': 5000,
          'duration_s': 1800,
          'pace_s_per_km': 360,
          'title': '本机合成运动卡',
        },
        'p_template_id': 'story',
        'p_template_version': 1,
        'p_client_nonce': const Uuid().v4(),
        'p_card_id': const Uuid().v4(),
        'p_route_bundle': null,
      },
    );
    expect(activityCard, isA<Map>());
    expect((activityCard as Map)['error'], isNull);

    await tester.tap(find.byTooltip('刷新消息'));
    await tester.pumpAndSettle();
    expect(find.text('群聊内容卡'), findsOneWidget);
    expect(find.text('运动记录卡'), findsOneWidget);

    // Verify the first account sees the second account's message through its
    // own authenticated RLS session, independent of the UI's current session.
    final firstClient = SupabaseClient(backend.url, backend.anonKey);
    await firstClient.auth.signInWithPassword(email: email, password: password);
    final visibleMessages = await firstClient
        .from('squad_messages')
        .select('body')
        .eq('squad_id', squadId)
        .eq('kind', 'text');
    expect(visibleMessages.any((row) => row['body'] == message), isTrue);
    final cardMessages = await firstClient
        .from('squad_messages')
        .select('card_id')
        .eq('squad_id', squadId)
        .eq('kind', 'card');
    expect(cardMessages.length, 2);
    final cardIds = cardMessages
        .map((row) => row['card_id'] as String)
        .toList();
    final visibleCards = await firstClient
        .from('card_snapshots')
        .select('id,snapshot')
        .inFilter('id', cardIds);
    expect(visibleCards.length, 2);
    final activitySnapshot =
        visibleCards.firstWhere(
              (row) => (row['snapshot'] as Map)['title'] == '本机合成运动卡',
            )['snapshot']
            as Map;
    expect(activitySnapshot.containsKey('avg_heart_rate_bpm'), isFalse);
    expect(activitySnapshot.containsKey('weight_kg'), isFalse);
    expect(activitySnapshot.containsKey('sleep_minutes'), isFalse);
    await firstClient.dispose();
    expect(find.text('双账号联调小队'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _register(
  WidgetTester tester,
  String email,
  String password,
  String nickname,
) async {
  await tester.tap(find.text('没有账号？去注册'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, '昵称'), nickname);
  await tester.enterText(find.widgetWithText(TextField, '邮箱'), email);
  await tester.enterText(find.widgetWithText(TextField, '密码'), password);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final register = find.widgetWithText(ElevatedButton, '注册');
  await tester.ensureVisible(register);
  await tester.pumpAndSettle();
  await tester.tap(register);
  await tester.pumpAndSettle();
  expect(find.text('会话'), findsOneWidget);
}

Future<void> _signOut(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.text('我的').last);
  await tester.pumpAndSettle();
  final signOut = find.widgetWithText(OutlinedButton, '退出登录');
  await tester.ensureVisible(signOut);
  await tester.pumpAndSettle();
  await tester.tap(signOut);
  await tester.pumpAndSettle();
  expect(find.text('邮箱登录'), findsOneWidget);
}

Future<void> _invokeIconAction(WidgetTester tester, String tooltip) async {
  final tooltipFinder = find.byTooltip(tooltip);
  final actionFinder = find.ancestor(
    of: tooltipFinder,
    matching: find.byType(IconButton),
  );
  tester.widget<IconButton>(actionFinder).onPressed!.call();
}

Future<void> _publishFromComposer(WidgetTester tester) async {
  final previewText = find.text('预览卡片');
  await tester.ensureVisible(previewText);
  tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, '预览卡片'))
      .onPressed!
      .call();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('确认发布到小队'));
  tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, '确认发布到小队'))
      .onPressed!
      .call();
  await tester.pumpAndSettle();
  tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, '确认发布'))
      .onPressed!
      .call();
  await tester.pumpAndSettle();
}
