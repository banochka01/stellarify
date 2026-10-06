import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/shared/widgets/ambient.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';

/// Живой фон по палитре обложки: медленно дрейфующие пятна света и
/// струящиеся «волны». Цвета плавно перетекают при смене трека, а при
/// отключённых анимациях фон застывает в спокойном кадре.
class AuroraBackdrop extends ConsumerStatefulWidget {
  const AuroraBackdrop({
    required this.track,
    this.intensity = 1,
    this.ribbons = true,
    this.animate = true,
    super.key,
  });

  final UnifiedTrack track;
  final double intensity;
  final bool ribbons;
  final bool animate;

  @override
  ConsumerState<AuroraBackdrop> createState() => _AuroraBackdropState();
}

class _AuroraBackdropState extends ConsumerState<AuroraBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 36),
  );

  // Декоративный цикл живёт, только пока играет музыка: на паузе
  // кадр застывает, а при отключённых анимациях не запускается вовсе.
  void _syncLoop() {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(AuroraBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncLoop();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchTrackPalette(ref, widget.track);
    return RepaintBoundary(
      child: TweenAnimationBuilder<TrackPalette>(
        tween: _AuroraPaletteTween(end: palette),
        duration: ResonanceMotion.durationOf(
          context,
          ResonanceMotion.gentle * 3,
        ),
        curve: ResonanceMotion.curve,
        builder: (context, value, _) => CustomPaint(
          painter: _AuroraPainter(
            clock: _clock,
            palette: value,
            intensity: widget.intensity,
            ribbons: widget.ribbons,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AuroraPaletteTween extends Tween<TrackPalette> {
  _AuroraPaletteTween({required TrackPalette end})
    : super(begin: end, end: end);

  @override
  TrackPalette lerp(double t) => TrackPalette.lerp(begin!, end!, t);
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.clock,
    required this.palette,
    required this.intensity,
    required this.ribbons,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final TrackPalette palette;
  final double intensity;
  final bool ribbons;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = clock.value * math.pi * 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF08060B),
    );

    final shortest = size.shortestSide;
    final longest = size.longestSide;
    final blobs = <(Color, double, Offset)>[
      (
        palette.glow,
        .46,
        Offset(.18 + .10 * math.sin(t), .30 + .14 * math.cos(t * 2)),
      ),
      (
        palette.shadow,
        .40,
        Offset(.78 + .12 * math.cos(t), .70 + .10 * math.sin(t * 2)),
      ),
      (
        palette.accent,
        .20,
        Offset(.55 + .22 * math.sin(t + 1.7), .18 + .08 * math.cos(t + .6)),
      ),
      (
        palette.glow,
        .18,
        Offset(.92 + .05 * math.sin(t * 3), .20 + .12 * math.cos(t)),
      ),
    ];
    for (final (color, alpha, anchor) in blobs) {
      final center = Offset(anchor.dx * size.width, anchor.dy * size.height);
      final radius =
          (shortest * .55 + longest * .30) *
          (1 + .06 * math.sin(t * 2 + anchor.dx * 5));
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha * intensity),
              color.withValues(alpha: alpha * .25 * intensity),
              color.withValues(alpha: 0),
            ],
            stops: const [0, .45, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    if (ribbons) {
      for (var i = 0; i < 3; i++) {
        final path = Path();
        final phase = t + i * 1.4;
        final baseY = size.height * (.38 + i * .16);
        final amplitude = size.height * (.08 + i * .025);
        path.moveTo(-20, baseY);
        for (double x = -20; x <= size.width + 20; x += 12) {
          final p = x / size.width;
          path.lineTo(
            x,
            baseY +
                math.sin(p * math.pi * 2.2 + phase) * amplitude +
                math.sin(p * math.pi * 5 - phase * 2) * amplitude * .22,
          );
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 22.0 - i * 6
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
            ..shader = LinearGradient(
              colors: [
                palette.accent.withValues(alpha: 0),
                palette.accent.withValues(alpha: (.20 - i * .05) * intensity),
                palette.glow.withValues(alpha: (.26 - i * .06) * intensity),
                palette.glow.withValues(alpha: 0),
              ],
              stops: const [0, .35, .75, 1],
            ).createShader(Offset.zero & size),
        );
      }
    }

    // Виньетка и нижнее затемнение держат контраст текста поверх фона.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x22000000), Color(0xCC08060B)],
          stops: [0, .6, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.intensity != intensity ||
      oldDelegate.ribbons != ribbons;
}
