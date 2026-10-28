import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/core/theme/app_tokens.dart';

void main() {
  group('AppTheme V1.0 layout tokens', () {
    test('shared spacing, radius, and touch target values are stable', () {
      expect(AppSpacing.md, 16);
      expect(AppSpacing.mdLg, 20);
      expect(AppSpacing.lg, 24);
      expect(AppRadii.compact, 8);
      expect(AppRadii.control, 14);
      expect(AppRadii.card, 16);
      expect(AppRadii.sheet, 24);
      expect(AppSizes.minimumTouchTarget, 48);
      expect(AppSizes.navigationBarHeight, 68);
    });

    test('theme controls use shared shape and touch target tokens', () {
      final theme = AppTheme.light();
      final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
      final filledButton = theme.filledButtonTheme.style!;
      final outlinedButton = theme.outlinedButtonTheme.style!;

      expect(cardShape.borderRadius, BorderRadius.circular(AppRadii.card));
      expect(
        (filledButton.shape!.resolve({})! as RoundedRectangleBorder)
            .borderRadius,
        BorderRadius.circular(AppRadii.control),
      );
      expect(
        (outlinedButton.shape!.resolve({})! as RoundedRectangleBorder)
            .borderRadius,
        BorderRadius.circular(AppRadii.control),
      );
      expect(
        filledButton.minimumSize!.resolve({}),
        const Size(AppSizes.minimumTouchTarget, AppSizes.minimumTouchTarget),
      );
      expect(
        outlinedButton.minimumSize!.resolve({}),
        const Size(AppSizes.minimumTouchTarget, AppSizes.minimumTouchTarget),
      );
      expect(theme.navigationBarTheme.height, AppSizes.navigationBarHeight);
    });
  });

  group('AppTheme V1.0 color tokens', () {
    test('light theme separates brand accent from readable action color', () {
      final theme = AppTheme.light();
      final palette = theme.extension<SquadlyPalette>()!;

      expect(theme.scaffoldBackgroundColor, const Color(0xFFF7F8FA));
      expect(theme.cardTheme.color, Colors.white);
      expect(theme.colorScheme.outlineVariant, const Color(0xFFE5E7EB));
      expect(palette.accent, const Color(0xFFFC6634));
      expect(palette.action, const Color(0xFFC2411A));
      expect(palette.accentSoft, const Color(0xFFFFF1EB));
      expect(theme.chipTheme.selectedColor, palette.accentSoft);
      expect(theme.chipTheme.checkmarkColor, palette.accent);
      expect(theme.chipTheme.labelStyle?.color, theme.colorScheme.onSurface);
      final segmented = theme.segmentedButtonTheme.style!;
      expect(
        segmented.backgroundColor!.resolve({WidgetState.selected}),
        palette.accentSoft,
      );
      expect(
        segmented.foregroundColor!.resolve({WidgetState.selected}),
        palette.action,
      );
      expect(segmented.backgroundColor!.resolve({}), theme.cardTheme.color);
      expect(
        theme.filledButtonTheme.style!.backgroundColor!.resolve({}),
        const Color(0xFFC2411A),
      );
      expect(
        theme.filledButtonTheme.style!.foregroundColor!.resolve({}),
        Colors.white,
      );
    });

    test('dark theme uses a light action surface with dark label text', () {
      final theme = AppTheme.dark();
      final palette = theme.extension<SquadlyPalette>()!;

      expect(theme.scaffoldBackgroundColor, const Color(0xFF0F1115));
      expect(theme.cardTheme.color, const Color(0xFF171A20));
      expect(theme.navigationBarTheme.backgroundColor, const Color(0xFF171A20));
      expect(palette.action, const Color(0xFFFF8A5C));
      expect(theme.chipTheme.selectedColor, palette.accentSoft);
      expect(theme.chipTheme.checkmarkColor, palette.accent);
      expect(theme.chipTheme.labelStyle?.color, theme.colorScheme.onSurface);
      final segmented = theme.segmentedButtonTheme.style!;
      expect(
        segmented.backgroundColor!.resolve({WidgetState.selected}),
        palette.accentSoft,
      );
      expect(
        segmented.foregroundColor!.resolve({WidgetState.selected}),
        palette.action,
      );
      expect(
        _contrastRatio(
          segmented.foregroundColor!.resolve({WidgetState.selected})!,
          segmented.backgroundColor!.resolve({WidgetState.selected})!,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        theme.filledButtonTheme.style!.backgroundColor!.resolve({}),
        const Color(0xFFFF8A5C),
      );
      expect(
        theme.filledButtonTheme.style!.foregroundColor!.resolve({}),
        const Color(0xFF1F2329),
      );
    });

    test('key text and action colors meet WCAG AA contrast targets', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final palette = theme.extension<SquadlyPalette>()!;
        final scheme = theme.colorScheme;
        final button = theme.filledButtonTheme.style!;
        final buttonBackground = button.backgroundColor!.resolve({})!;
        final buttonForeground = button.foregroundColor!.resolve({})!;
        final segmented = theme.segmentedButtonTheme.style!;
        final selectedBackground = segmented.backgroundColor!.resolve({
          WidgetState.selected,
        })!;
        final selectedForeground = segmented.foregroundColor!.resolve({
          WidgetState.selected,
        })!;

        expect(
          _contrastRatio(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(buttonForeground, buttonBackground),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(selectedForeground, selectedBackground),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(palette.action, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(palette.success, scheme.surface),
          greaterThanOrEqualTo(3),
        );
      }
    });
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
