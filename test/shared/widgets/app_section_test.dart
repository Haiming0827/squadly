import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/shared/widgets/app_section.dart';

void main() {
  testWidgets('metric icons use the readable action token', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Row(
            children: [
              MetricTile(label: '任务', value: '1/2', icon: Icons.task_alt),
            ],
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.task_alt));
    expect(icon.color, AppTheme.action);
  });
}
