import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Resonance 5.0 design tokens.
///
/// Single source of truth for spacing, radii, elevation, typography and
/// colour contrast. Feature screens (including new 5.0 sections) should read
/// these instead of hard-coding magic numbers.

/// 4-pt spacing scale.
abstract final class ResonanceSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter for a given viewport width.
  static double gutter(double width) {
    if (width < 400) return lg;
    if (width < 760) return 20;
    if (width < 1200) return xxl;
    return 44;
  }
}

/// Corner radii.
abstract final class ResonanceRadii {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 999;

  static BorderRadius all(double value) => BorderRadius.circular(value);
  static final BorderRadius card = BorderRadius.circular(lg);
  static final BorderRadius tile = BorderRadius.circular(md);
  static final BorderRadius artwork = BorderRadius.circular(sm);
  static final BorderRadius hero = BorderRadius.circular(xl);
}

/// Layered, warm-black shadows tuned for the dark UI.
abstract final class ResonanceShadows {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> low = [
    BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 3)),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x52000000), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> high = [
    BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x73000000), blurRadius: 48, offset: Offset(0, 24)),
  ];

  /// Coloured glow behind large artwork (dynamic accent).
  static List<BoxShadow> glow(Color color, {double strength = 1}) => [
    BoxShadow(
      color: color.withValues(alpha: .22 * strength),
      blurRadius: 72,
      spreadRadius: -18,
      offset: const Offset(0, 18),
    ),
    // Мягкая контактная тень без «плиты» под обложкой.
    const BoxShadow(
      color: Color(0x40000000),
      blurRadius: 36,
      spreadRadius: -10,
      offset: Offset(0, 14),
    ),
  ];
}

/// Typography scale mirroring the 4.0 «Эфир» text theme (Unbounded for
/// screen titles, Manrope for everything else, JetBrains Mono for labels).
abstract final class ResonanceType {
  static const display = TextStyle(
    fontFamily: 'Unbounded',
    fontSize: 30,
    height: 1.06,
    fontWeight: FontWeight.w600,
    letterSpacing: -.8,
  );
  static const headline = TextStyle(
    fontSize: 24,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -.5,
  );
  static const title = TextStyle(
    fontSize: 19,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -.3,
  );
  static const subtitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 14, height: 1.5);
  static const caption = TextStyle(fontSize: 12, height: 1.4);
  static const overline = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );
}

/// Breakpoints shared by every adaptive layout.
abstract final class ResonanceBreakpoints {
  static const double compact = 600;
  static const double medium = 900;
  static const double expanded = 1200;

  static bool isCompact(double width) => width < compact;
  static bool isDesktop(double width) => width >= medium;
}

/// WCAG 2.x contrast helpers.
abstract final class ResonanceContrast {
  static double ratio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + .05) / (lo + .05);
  }

  /// Body text minimum (AA).
  static const double aa = 4.5;

  /// Large text / UI component minimum (AA).
  static const double aaLarge = 3;

  /// Black or white, whichever reads better on [background].
  static Color onColor(Color background) =>
      ratio(background, Colors.white) >=
          ratio(background, const Color(0xFF090706))
      ? Colors.white
      : const Color(0xFF090706);

  /// Lightens [color] (in HSL) until it reaches [minRatio] against
  /// [background]. Used to make cover-derived accents legible.
  static Color ensure(
    Color color,
    Color background, {
    double minRatio = aaLarge,
  }) {
    var hsl = HSLColor.fromColor(color);
    var result = color;
    var guard = 0;
    while (ratio(result, background) < minRatio && guard < 24) {
      hsl = hsl.withLightness(math.min(1, hsl.lightness + .04));
      result = hsl.toColor();
      guard++;
    }
    return result;
  }
}

/// Theme extension exposing tokens that depend on the active preset.
@immutable
class ResonanceTokens extends ThemeExtension<ResonanceTokens> {
  const ResonanceTokens({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.accent,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color accent;
  final Color text;

  /// Secondary text; guaranteed AA (4.5:1) on [surfaceRaised].
  final Color textMuted;

  /// Tertiary labels; guaranteed 3:1 on [surfaceRaised].
  final Color textSubtle;
  final Color skeletonBase;
  final Color skeletonHighlight;

  static ResonanceTokens of(BuildContext context) =>
      Theme.of(context).extension<ResonanceTokens>() ?? fallback;

  static const fallback = ResonanceTokens(
    background: Color(0xFF0E0B14),
    surface: Color(0xFF17121F),
    surfaceRaised: Color(0xFF211A2C),
    border: Color(0xFF302640),
    accent: Color(0xFFB69CFF),
    text: Color(0xFFEFE9F5),
    textMuted: Color(0xFF9A8FAB),
    textSubtle: Color(0xFF827896),
    skeletonBase: Color(0xFF1C1626),
    skeletonHighlight: Color(0xFF2A2236),
  );

  @override
  ResonanceTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? accent,
    Color? text,
    Color? textMuted,
    Color? textSubtle,
    Color? skeletonBase,
    Color? skeletonHighlight,
  }) => ResonanceTokens(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    border: border ?? this.border,
    accent: accent ?? this.accent,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    textSubtle: textSubtle ?? this.textSubtle,
    skeletonBase: skeletonBase ?? this.skeletonBase,
    skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
  );

  @override
  ResonanceTokens lerp(ThemeExtension<ResonanceTokens>? other, double t) {
    if (other is! ResonanceTokens) return this;
    return ResonanceTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight: Color.lerp(
        skeletonHighlight,
        other.skeletonHighlight,
        t,
      )!,
    );
  }
}
