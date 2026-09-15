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
  static const spotify = Color(0xFF1DB954);
  static const vk = Color(0xFF4C8EF9);
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
      hoverColor: palette.secondary.withValues(alpha: .055),
      focusColor: palette.primary.withValues(alpha: .16),
      highlightColor: palette.primary.withValues(alpha: .1),
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
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.primary.withValues(alpha: .2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: .1,
            color: selected ? ResonanceColors.text : ResonanceColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected)
                ? palette.primary
                : ResonanceColors.muted,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ResonanceColors.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ResonanceColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        minLeadingWidth: 40,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.square(44)),
          iconSize: const WidgetStatePropertyAll(22),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return palette.primary.withValues(alpha: .2);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return palette.secondary.withValues(alpha: .1);
            }
            return null;
          }),
        ),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: Colors.black.withValues(alpha: .55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.raised,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: .68),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.raised,
        contentTextStyle: const TextStyle(color: ResonanceColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border),
        ),
        textStyle: const TextStyle(color: ResonanceColors.text, fontSize: 12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.border,
        circularTrackColor: palette.border,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(5),
        radius: const Radius.circular(99),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? palette.secondary.withValues(alpha: .48)
              : palette.secondary.withValues(alpha: .24),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.primary,
        selectionColor: palette.primary.withValues(alpha: .28),
        selectionHandleColor: palette.primary,
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
