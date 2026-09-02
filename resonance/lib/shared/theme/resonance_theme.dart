import 'package:flutter/material.dart';
import 'package:resonance/core/preferences/appearance_preferences.dart';

abstract final class ResonanceColors {
  static const background = Color(0xFF060606);
  static const surface = Color(0xFF0D0D0D);
  static const surfaceHigh = Color(0xFF151514);
  static const surfaceRaised = Color(0xFF1B1A18);
  static const border = Color(0xFF2A2927);
  static const primary = Color(0xFFFF5A36);
  static const secondary = Color(0xFFF1ECE2);
  static const success = Color(0xFF5DDAA3);
  static const text = Color(0xFFF4F4F2);
  static const muted = Color(0xFF858585);
  static const youtube = Color(0xFFFF5A63);
  static const yandex = Color(0xFFFFD84A);
  static const soundcloud = Color(0xFFFF783E);
}

abstract final class ResonanceTheme {
  static ThemeData forPreset(ResonanceThemePreset preset) {
    final palette = switch (preset) {
      ResonanceThemePreset.graphite => const _Palette(
        background: Color(0xFF060606),
        surface: Color(0xFF0D0D0D),
        raised: Color(0xFF1B1A18),
        border: Color(0xFF2A2927),
        primary: Color(0xFFFF5A36),
        secondary: Color(0xFFF1ECE2),
      ),
      ResonanceThemePreset.midnight => const _Palette(
        background: Color(0xFF070712),
        surface: Color(0xFF101020),
        raised: Color(0xFF1B1B35),
        border: Color(0xFF32325A),
        primary: Color(0xFF8B7CFF),
        secondary: Color(0xFFDCD8FF),
      ),
      ResonanceThemePreset.ember => const _Palette(
        background: Color(0xFF100706),
        surface: Color(0xFF190D0B),
        raised: Color(0xFF2A1612),
        border: Color(0xFF4B2922),
        primary: Color(0xFFFF704D),
        secondary: Color(0xFFFFE1D8),
      ),
    };
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: Brightness.dark,
          surface: palette.surface,
        ).copyWith(
          primary: palette.primary,
          secondary: palette.secondary,
          surface: palette.surface,
          surfaceContainerLowest: palette.background,
          surfaceContainerHigh: palette.raised,
          outline: palette.border,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Inter',
      dividerColor: palette.border,
      cardColor: palette.surface,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 48,
          height: 0.95,
          fontWeight: FontWeight.w800,
          letterSpacing: -2.3,
          color: ResonanceColors.text,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: ResonanceColors.muted, height: 1.45),
        labelLarge: TextStyle(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: palette.surface.withValues(alpha: .92),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.border),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        backgroundColor: Color(0xFF0A0A09),
        indicatorColor: Color(0x33FF5A36),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .1,
          ),
        ),
        iconTheme: WidgetStatePropertyAll(IconThemeData(size: 21)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ResonanceColors.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ResonanceColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Color(0xFF090706),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ResonanceColors.text,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ResonanceColors.surfaceHigh,
        selectedColor: palette.primary,
        disabledColor: ResonanceColors.surfaceHigh,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          color: ResonanceColors.text,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: palette.border),
        ),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.raised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.primary),
        ),
      ),
    );
  }
}

final class _Palette {
  const _Palette({
    required this.background,
    required this.surface,
    required this.raised,
    required this.border,
    required this.primary,
    required this.secondary,
  });
  final Color background;
  final Color surface;
  final Color raised;
  final Color border;
  final Color primary;
  final Color secondary;
}
