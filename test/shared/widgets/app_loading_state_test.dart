import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/shared/widgets/app_loading_state.dart';

void main() {
  testWidgets('loading state shows a visible label and named progress', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppLoadingState(label: '正在加载理财数据…')),
      ),
    );

    expect(find.text('正在加载理财数据…'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(CircularProgressIndicator)).label,
      '正在加载理财数据…',
    );
    semantics.dispose();
  });
}
