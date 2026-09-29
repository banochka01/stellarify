import 'package:flutter/material.dart';
import 'package:resonance/core/preferences/appearance_preferences.dart';

abstract final class ResonanceColors {
  // «Эфир»: баклажанная ночь, сиреневый — действие, лайм — то, что live.
  static const background = Color(0xFF0E0B14);
  static const surface = Color(0xFF17121F);
  static const surfaceHigh = Color(0xFF1C1626);
  static const surfaceRaised = Color(0xFF211A2C);
  static const border = Color(0xFF302640);
  static const primary = Color(0xFFB69CFF);
  static const secondary = Color(0xFFEFE9F5);
  static const live = Color(0xFFD8F15A);
  static const success = Color(0xFF5DDAA3);
  static const text = Color(0xFFEFE9F5);
  static const muted = Color(0xFF9A8FAB);
  static const youtube = Color(0xFFFF5A63);
  static const yandex = Color(0xFFFFD84A);
  static const soundcloud = Color(0xFFFF783E);
  static const spotify = Color(0xFF1DB954);
  static const vk = Color(0xFF4C8EF9);
}

abstract final class ResonanceFonts {
  static const body = 'Manrope';
  static const display = 'Unbounded';
  static const mono = 'JetBrainsMono';
}

abstract final class ResonanceTheme {
  static ThemeData forPreset(ResonanceThemePreset preset) {
    // Имена пресетов сохранены ради совместимости с сохранёнными настройками:
    // graphite теперь «Эфир» (по умолчанию), midnight — «Графит», ember — «Янтарь».
    final palette = switch (preset) {
      ResonanceThemePreset.graphite => const _Palette(
        background: Color(0xFF0E0B14),
        surface: Color(0xFF17121F),
        raised: Color(0xFF211A2C),
        border: Color(0xFF302640),
        primary: Color(0xFFB69CFF),
        secondary: Color(0xFFEFE9F5),
      ),
      ResonanceThemePreset.midnight => const _Palette(
        background: Color(0xFF0A0A0C),
        surface: Color(0xFF131316),
        raised: Color(0xFF1D1D22),
        border: Color(0xFF2E2E36),
        primary: Color(0xFFC9C3FF),
        secondary: Color(0xFFEDEDF2),
      ),
      ResonanceThemePreset.ember => const _Palette(
        background: Color(0xFF120A08),
        surface: Color(0xFF1B100D),
        raised: Color(0xFF2A1813),
        border: Color(0xFF4B2922),
        primary: Color(0xFFFF8A5B),
        secondary: Color(0xFFFFE8DE),
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
      fontFamily: ResonanceFonts.body,
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
        displayLarge: TextStyle(
          fontFamily: ResonanceFonts.display,
          fontSize: 56,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.6,
          color: ResonanceColors.text,
        ),
        displayMedium: TextStyle(
          fontFamily: ResonanceFonts.display,
          fontSize: 44,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          color: ResonanceColors.text,
        ),
        displaySmall: TextStyle(
          fontFamily: ResonanceFonts.display,
          fontSize: 36,
          height: 1.02,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
          color: ResonanceColors.text,
        ),
        headlineMedium: TextStyle(
          fontFamily: ResonanceFonts.display,
          fontSize: 26,
          height: 1.08,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
        ),
        headlineSmall: TextStyle(
          fontFamily: ResonanceFonts.display,
          fontSize: 20,
          height: 1.1,
          fontWeight: FontWeight.w600,
          letterSpacing: -.4,
        ),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(height: 1.5),
        bodyMedium: TextStyle(color: ResonanceColors.muted, height: 1.5),
        labelLarge: TextStyle(fontWeight: FontWeight.w800),
        labelSmall: TextStyle(
          fontFamily: ResonanceFonts.mono,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface.withValues(alpha: .92),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: palette.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.primary,
        indicatorShape: const StadiumBorder(),
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
                ? palette.background
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
          foregroundColor: ResonanceColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ResonanceColors.text,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ResonanceColors.surfaceHigh,
        selectedColor: palette.primary,
        disabledColor: ResonanceColors.surfaceHigh,
        labelStyle: const TextStyle(
          fontFamily: ResonanceFonts.body,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: ResonanceFonts.body,
          color: ResonanceColors.text,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
          side: BorderSide(color: palette.border),
        ),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.raised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
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
