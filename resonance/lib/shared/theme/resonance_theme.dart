import 'package:flutter/material.dart';

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
  static ThemeData get dark {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: ResonanceColors.primary,
          brightness: Brightness.dark,
          surface: ResonanceColors.surface,
        ).copyWith(
          primary: ResonanceColors.primary,
          secondary: ResonanceColors.secondary,
          surface: ResonanceColors.surface,
          outline: ResonanceColors.border,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ResonanceColors.background,
      fontFamily: 'Inter',
      dividerColor: ResonanceColors.border,
      cardColor: ResonanceColors.surface,
      splashFactory: InkSparkle.splashFactory,
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
        color: const Color(0xE6101010),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: ResonanceColors.border),
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
          backgroundColor: ResonanceColors.primary,
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
          side: const BorderSide(color: ResonanceColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ResonanceColors.surfaceHigh,
        selectedColor: ResonanceColors.primary,
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
          side: const BorderSide(color: ResonanceColors.border),
        ),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ResonanceColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ResonanceColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ResonanceColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ResonanceColors.primary),
        ),
      ),
    );
  }
}
