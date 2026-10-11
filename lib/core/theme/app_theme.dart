import 'package:flutter/material.dart';

@immutable
class SquadlyPalette extends ThemeExtension<SquadlyPalette> {
  const SquadlyPalette({
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.info,
    required this.privacy,
  });

  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color info;
  final Color privacy;

  @override
  SquadlyPalette copyWith({
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? info,
    Color? privacy,
  }) {
    return SquadlyPalette(
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      info: info ?? this.info,
      privacy: privacy ?? this.privacy,
    );
  }

  @override
  SquadlyPalette lerp(covariant SquadlyPalette? other, double t) {
    if (other == null) return this;
    return SquadlyPalette(
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      privacy: Color.lerp(privacy, other.privacy, t)!,
    );
  }
}

extension SquadlyTheme on BuildContext {
  SquadlyPalette get squadlyPalette =>
      Theme.of(this).extension<SquadlyPalette>()!;
}

/// Humanized Quiet Utility 视觉主题。
class AppTheme {
  AppTheme._();

  static const accent = Color(0xFFFF5A3C);

  static ThemeData light() {
    const colors = ColorScheme.light(
      primary: Color(0xFF202329),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF626A76),
      onSecondary: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF17191D),
      error: Color(0xFFC83D4A),
      onError: Color(0xFFFFFFFF),
      outline: Color(0xFFD7DAE0),
      outlineVariant: Color(0xFFE7E9ED),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF8F9FA),
      surfaceContainer: Color(0xFFF3F4F6),
      surfaceContainerHigh: Color(0xFFEFF1F4),
    );
    return _base(
      colors,
      const SquadlyPalette(
        accent: accent,
        accentSoft: Color(0xFFFFF0EB),
        success: Color(0xFF16865D),
        info: Color(0xFF3276D2),
        privacy: Color(0xFF6658C8),
      ),
    );
  }

  static ThemeData dark() {
    const colors = ColorScheme.dark(
      primary: Color(0xFFF5F7FA),
      onPrimary: Color(0xFF17191D),
      secondary: Color(0xFFAAB1BC),
      onSecondary: Color(0xFF17191D),
      surface: Color(0xFF0F1115),
      onSurface: Color(0xFFF5F7FA),
      error: Color(0xFFFF6B76),
      onError: Color(0xFF17191D),
      outline: Color(0xFF3A414C),
      outlineVariant: Color(0xFF2D333D),
      surfaceContainerLowest: Color(0xFF0F1115),
      surfaceContainerLow: Color(0xFF15181D),
      surfaceContainer: Color(0xFF171A20),
      surfaceContainerHigh: Color(0xFF1D2128),
    );
    return _base(
      colors,
      const SquadlyPalette(
        accent: Color(0xFFFF6A4A),
        accentSoft: Color(0xFF3A211C),
        success: Color(0xFF3CCB91),
        info: Color(0xFF6EA8FF),
        privacy: Color(0xFF9B8CFF),
      ),
    );
  }

  static ThemeData _base(ColorScheme colors, SquadlyPalette palette) {
    final base = ThemeData(
      useMaterial3: true,
      // InkRipple is materially identical across Android/iOS and does not
      // depend on the Android-only sparkle fragment shader at runtime.
      splashFactory: InkRipple.splashFactory,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      extensions: [palette],
    );
    final textTheme = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: colors.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outline),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surface,
        modalBarrierColor: Colors.black.withValues(alpha: 0.42),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: colors.surface,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? colors.onSurface : colors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: TextStyle(color: colors.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
