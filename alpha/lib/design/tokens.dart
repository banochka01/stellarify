import 'package:flutter/material.dart';

/// Resonance α visual language: a black stage, warm paper-white ink and one
/// loud colour that is always taken from the artwork that is playing.
abstract final class Pal {
  static const stage = Color(0xFF050505);
  static const raised = Color(0xFF111111);
  static const line = Color(0x1FFFFFFF);
  static const paper = Color(0xFFF2EFE6);
  static const muted = Color(0x99F2EFE6);
  static const faint = Color(0x52F2EFE6);

  /// Sage: the accent before anything has played.
  static const acid = Color(0xFFB4C9A4);
}

abstract final class Txt {
  static TextStyle display(double size, {Color color = Pal.paper}) => TextStyle(
    fontFamily: 'Unbounded',
    fontSize: size,
    height: .92,
    letterSpacing: -size * .045,
    color: color,
    fontWeight: FontWeight.w800,
    fontVariations: const [FontVariation('wght', 820)],
  );

  static TextStyle title(double size, {Color color = Pal.paper}) => TextStyle(
    fontFamily: 'Unbounded',
    fontSize: size,
    height: 1.05,
    letterSpacing: -size * .02,
    color: color,
    fontWeight: FontWeight.w600,
    fontVariations: const [FontVariation('wght', 620)],
  );

  static TextStyle body(
    double size, {
    Color color = Pal.paper,
    double weight = 500,
  }) => TextStyle(
    fontFamily: 'Manrope',
    fontSize: size,
    height: 1.3,
    color: color,
    fontWeight: weight >= 650 ? FontWeight.w700 : FontWeight.w500,
    fontVariations: [FontVariation('wght', weight)],
  );

  /// Monospaced labels: indices, timecodes, section numbers.
  static TextStyle mono(double size, {Color color = Pal.muted}) => TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: size,
    height: 1.2,
    letterSpacing: size * .06,
    color: color,
    fontWeight: FontWeight.w500,
    fontVariations: const [FontVariation('wght', 520)],
  );
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 700);
  static const curve = Curves.easeOutCubic;
  static const spring = Cubic(.2, 1.4, .4, 1);
}

ThemeData alphaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Pal.acid,
    brightness: Brightness.dark,
  ).copyWith(surface: Pal.stage, primary: Pal.acid, onPrimary: Pal.stage);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Pal.stage,
    fontFamily: 'Manrope',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.white10,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Pal.acid,
      selectionColor: Color(0x55B4C9A4),
      selectionHandleColor: Pal.acid,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Pal.paper,
      contentTextStyle: Txt.body(14, color: Pal.stage, weight: 650),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thickness: WidgetStatePropertyAll(4),
      thumbColor: WidgetStatePropertyAll(Color(0x33FFFFFF)),
    ),
  );
}
