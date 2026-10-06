import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

/// Continuous decorative motion (ambient backdrops, equalizer bars). Disabled
/// under `flutter test` so `pumpAndSettle` can finish, and overridable.
final ambientMotionEnabledProvider = Provider<bool>((ref) {
  return !Platform.environment.containsKey('FLUTTER_TEST');
});

/// Three colors that describe a piece of artwork on a dark surface.
@immutable
final class ArtworkPalette {
  const ArtworkPalette({
    required this.accent,
    required this.glow,
    required this.deep,
  });

  static const fallback = ArtworkPalette(
    accent: Color(0xFFFF6A43),
    glow: Color(0xFF7B4BFF),
    deep: Color(0xFF2A120C),
  );

  final Color accent;
  final Color glow;
  final Color deep;

  /// Readable foreground on top of [accent] (the play button, the pills).
  Color get onAccent =>
      accent.computeLuminance() > .45 ? const Color(0xFF0B0B0B) : Colors.white;

  static ArtworkPalette lerp(ArtworkPalette a, ArtworkPalette b, double t) =>
      ArtworkPalette(
        accent: Color.lerp(a.accent, b.accent, t)!,
        glow: Color.lerp(a.glow, b.glow, t)!,
        deep: Color.lerp(a.deep, b.deep, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is ArtworkPalette &&
      other.accent == accent &&
      other.glow == glow &&
      other.deep == deep;

  @override
  int get hashCode => Object.hash(accent, glow, deep);
}

/// Palette extracted from artwork, cached per URL for the app session.
final artworkPaletteProvider = FutureProvider.family<ArtworkPalette, String?>((
  ref,
  url,
) async {
  if (url == null || !ref.watch(ambientMotionEnabledProvider)) {
    return ArtworkPalette.fallback;
  }
  try {
    final scheme = await ColorScheme.fromImageProvider(
      provider: ResizeImage(
        CachedNetworkImageProvider(url),
        width: 96,
        height: 96,
        policy: ResizeImagePolicy.fit,
      ),
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).timeout(const Duration(seconds: 6));
    return paletteFromScheme(scheme);
  } on Object {
    return ArtworkPalette.fallback;
  }
});

ArtworkPalette paletteFromScheme(ColorScheme scheme) {
  final accent = _vivid(scheme.primary);
  final glowSource = HSLColor.fromColor(scheme.tertiary);
  final accentHue = HSLColor.fromColor(accent).hue;
  // Keep the secondary glow visibly different from the accent so the
  // backdrop never collapses into one flat tint.
  final glow = (glowSource.hue - accentHue).abs() < 24
      ? HSLColor.fromColor(accent).withHue((accentHue + 38) % 360)
      : glowSource;
  final deep = HSLColor.fromColor(accent);
  return ArtworkPalette(
    accent: accent,
    glow: glow
        .withSaturation(math.min(.85, glow.saturation + .15))
        .withLightness(.55)
        .toColor(),
    deep: deep
        .withLightness(.12)
        .withSaturation(math.min(.7, deep.saturation))
        .toColor(),
  );
}

Color _vivid(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation(math.max(.45, hsl.saturation))
      .withLightness(hsl.lightness.clamp(.52, .68))
      .toColor();
}

/// Watches the palette for [url] and keeps the previous palette while the
/// next one is extracted, so the background never flashes to the default.
ArtworkPalette watchArtworkPalette(WidgetRef ref, Uri? url) {
  final value = ref.watch(artworkPaletteProvider(url?.toString()));
  return value.valueOrNull ?? ArtworkPalette.fallback;
}

/// A slow, living backdrop: blurred artwork, drifting color fields and soft
/// light ribbons tinted by the artwork palette. Colors cross-fade when the
/// palette changes; motion stops entirely with reduced motion.
class AmbientBackdrop extends ConsumerStatefulWidget {
  const AmbientBackdrop({
    required this.palette,
    this.imageUrl,
    this.ribbons = true,
    this.intensity = 1,
    this.fadeTo = ResonanceColors.background,
    super.key,
  });

  final ArtworkPalette palette;
  final Uri? imageUrl;
  final bool ribbons;
  final double intensity;
  final Color fadeTo;

  @override
  ConsumerState<AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends ConsumerState<AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );
  late ArtworkPalette _from = widget.palette;

  @override
  void didUpdateWidget(AmbientBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.palette != widget.palette) _from = oldWidget.palette;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final enabled = ref.read(ambientMotionEnabledProvider) && !reduced;
    if (enabled && !_drift.isAnimating) {
      unawaited(_drift.repeat());
    } else if (!enabled && _drift.isAnimating) {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.imageUrl;
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.palette),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final palette = ArtworkPalette.lerp(_from, widget.palette, t);
        // Fade to transparent instead of a solid color, so the backdrop
        // melts into whatever surface sits behind the page.
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
            stops: [0, .5, 1],
          ).createShader(bounds),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Color.lerp(widget.fadeTo, palette.deep, .55)!),
              if (image != null)
                Opacity(
                  opacity: .34 * widget.intensity,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: 48,
                      sigmaY: 48,
                      tileMode: TileMode.decal,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: image.toString(),
                      fit: BoxFit.cover,
                      memCacheWidth: 320,
                      fadeInDuration: const Duration(milliseconds: 600),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: _AmbientPainter(
                    animation: _drift,
                    palette: palette,
                    ribbons: widget.ribbons,
                    intensity: widget.intensity,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .05),
                      Colors.black.withValues(alpha: .32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.animation,
    required this.palette,
    required this.ribbons,
    required this.intensity,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final ArtworkPalette palette;
  final bool ribbons;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Blobs are larger than the canvas; never let them leak below the fade.
    canvas.clipRect(Offset.zero & size);
    final phase = animation.value * math.pi * 2;
    final shortest = size.shortestSide;

    void blob(Color color, double alpha, Offset center, double radius) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha * intensity),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    blob(
      palette.accent,
      .55,
      Offset(
        size.width * (.22 + .08 * math.sin(phase)),
        size.height * (.32 + .1 * math.cos(phase * 2)),
      ),
      math.max(size.width * .42, shortest * .8),
    );
    blob(
      palette.glow,
      .38,
      Offset(
        size.width * (.78 + .07 * math.cos(phase + 1.3)),
        size.height * (.22 + .12 * math.sin(phase + .4)),
      ),
      math.max(size.width * .36, shortest * .7),
    );
    blob(
      Color.lerp(palette.accent, palette.glow, .5)!,
      .22,
      Offset(
        size.width * (.55 + .18 * math.sin(phase * 1.0 + 2.1)),
        size.height * (.75 + .08 * math.cos(phase + .7)),
      ),
      shortest * .9,
    );

    if (!ribbons) return;
    // Light ribbons: layered sine strokes that slowly breathe, echoing a
    // sound wave without drawing an obvious waveform.
    for (var layer = 0; layer < 3; layer++) {
      final path = Path();
      final amplitude = size.height * (.09 + layer * .035);
      final baseline = size.height * (.42 + layer * .09);
      final shift = phase + layer * 1.7;
      const steps = 48;
      for (var i = 0; i <= steps; i++) {
        final x = size.width * (i / steps) * 1.1 - size.width * .05;
        final u = i / steps * math.pi * 2;
        final y =
            baseline +
            math.sin(u * 1.2 + shift) * amplitude +
            math.sin(u * 2.7 - shift * 1.3) * amplitude * .35;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final color = layer.isEven ? palette.accent : palette.glow;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = shortest * (.05 - layer * .012)
          ..color = color.withValues(alpha: (.16 - layer * .035) * intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: (.26 - layer * .06) * intensity),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.ribbons != ribbons ||
      oldDelegate.intensity != intensity;
}

/// Three small bars that bounce while [playing]; static otherwise.
class EqualizerBars extends ConsumerStatefulWidget {
  const EqualizerBars({
    required this.playing,
    this.color = Colors.white,
    this.size = 16,
    super.key,
  });

  final bool playing;
  final Color color;
  final double size;

  @override
  ConsumerState<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends ConsumerState<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(EqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animate =
        widget.playing && !reduced && ref.read(ambientMotionEnabledProvider);
    if (animate && !_controller.isAnimating) {
      unawaited(_controller.repeat());
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * math.pi * 2;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: widget.size / 5,
                  height:
                      widget.size *
                      (widget.playing
                          ? .3 + .7 * (.5 + .5 * math.sin(t + i * 2.1)).abs()
                          : .35 + i % 2 * .25),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
