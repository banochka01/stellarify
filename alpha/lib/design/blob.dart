import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:resonance_alpha/audio/level.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/tokens.dart';

/// A living shape: a solid accent mass that breathes slowly when idle and
/// churns while music plays. Text passed in [label] is set inside the
/// shape in a deep shade of the same colour.
class LivingBlob extends StatefulWidget {
  const LivingBlob({
    required this.color,
    required this.energy,
    this.label,
    this.labelSize = 64,
    this.sampler,
    super.key,
  });

  final Color color;

  /// 0 — asleep, 1 — playing loud.
  final double energy;
  final String? label;
  final double labelSize;

  /// Live loudness of the music. When present the mass swells with the
  /// level and kicks on transients, instead of breathing on a formula.
  final LevelSampler? sampler;

  @override
  State<LivingBlob> createState() => _LivingBlobState();
}

class _LivingBlobState extends State<LivingBlob>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  double _energy = 0;
  Duration _last = Duration.zero;

  // Live sound: a smoothed envelope plus a short kick on each transient.
  final _sound = _Sound();
  bool _sampling = false;
  double _sinceSample = 0;

  @override
  void initState() {
    super.initState();
    _energy = widget.energy;
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // Energy eases towards the target so play/pause morphs, never snaps.
    _energy += (widget.energy - _energy) * math.min(1, dt * 2.4);
    _sound.decay(dt);
    _sinceSample += dt;
    final sampler = widget.sampler;
    if (sampler != null && widget.energy > .5 && !_sampling &&
        _sinceSample >= 1 / 30) {
      _sinceSample = 0;
      _sampling = true;
      sampler().then((value) {
        if (value != null) _sound.feed(value);
      }).whenComplete(() => _sampling = false);
    }
    if (widget.energy <= .5) _sound.feed(0);
    _time.value += dt * (.35 + _energy * .9 + _sound.kick * .8);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BlobPainter(
          time: _time,
          color: widget.color,
          energy: () => _energy,
          sound: _sound,
          label: widget.label,
          labelSize: widget.labelSize,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({
    required this.time,
    required this.color,
    required this.energy,
    required this.sound,
    required this.label,
    required this.labelSize,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final Color color;
  final double Function() energy;
  final _Sound sound;
  final String? label;
  final double labelSize;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final e = energy();
    final center = size.center(Offset.zero);
    final live = sound.active;
    final swell = live ? sound.envelope * .07 + sound.kick * .09 : 0.0;
    final radius = math.min(size.width, size.height) * .34 * (1 + swell);
    final jolt = live ? sound.kick * .14 : 0.0;

    // Halo: a wide, blurred copy of the shape.
    final halo = _shape(center, radius * 1.18, t * .7, .1 + e * .08);
    canvas.drawPath(
      halo,
      Paint()
        ..color = color.withValues(alpha: .08 + e * .08 + swell * .9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );

    // Ghost outlines trailing behind the mass.
    for (var i = 3; i >= 1; i--) {
      final ring = _shape(
        center,
        radius * (1 + i * (.07 + jolt * .25)),
        t - i * .22,
        .12 + e * .1,
      );
      canvas.drawPath(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: .2 - i * .05),
      );
    }

    final body = _shape(center, radius, t, .09 + e * .13 + jolt);
    final bounds = body.getBounds();
    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(math.sin(t * .9) * .5, math.cos(t * .6) * .5 - .2),
          radius: .9,
          colors: [
            Color.lerp(color, Colors.white, .16)!,
            color,
            Color.lerp(color, Colors.black, .18)!,
          ],
          stops: const [0, .6, 1],
        ).createShader(bounds),
    );

    final text = label;
    if (text == null || text.isEmpty) return;
    // The label lives inside the shape: shrink until it fits the mass.
    var fontSize = labelSize;
    TextPainter layout() => TextPainter(
      text: TextSpan(
        text: text,
        style: Txt.display(fontSize, color: inkOn(color)),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: radius * 1.6);
    var painter = layout();
    while ((painter.height > radius * 1.3 || painter.didExceedMaxLines) &&
        fontSize > 18) {
      painter.dispose();
      fontSize *= .9;
      painter = layout();
    }
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  /// A closed organic outline built from layered sine waves around a circle.
  Path _shape(Offset c, double r, double t, double wobble) {
    const points = 96;
    final path = Path();
    for (var i = 0; i <= points; i++) {
      final a = i / points * math.pi * 2;
      final k =
          1 +
          wobble *
              (math.sin(a * 2 + t * 1.3) * .55 +
                  math.sin(a * 3 - t * 1.7 + 1.2) * .3 +
                  math.sin(a * 5 + t * 2.3 + .4) * .15);
      final p = c + Offset(math.cos(a) * r * k, math.sin(a) * r * k * .96);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.color != color || old.label != label || old.labelSize != labelSize;
}

/// Envelope follower over sampled peaks: fast attack, slow release, and a
/// kick that fires when the level jumps above its recent average.
final class _Sound {
  double envelope = 0;
  double kick = 0;
  double _average = 0;
  double _quietFor = 10;

  bool get active => _quietFor < 1.5;

  void feed(double level) {
    // Peaks are linear amplitude; the ear is logarithmic.
    final value = level <= 0
        ? 0.0
        : ((20 * math.log(level) / math.ln10 + 42) / 42).clamp(0.0, 1.0);
    if (value > .02) _quietFor = 0;
    envelope += (value - envelope) * (value > envelope ? .55 : .12);
    final rise = value - _average;
    if (rise > .08) kick = math.max(kick, (rise * 3.2).clamp(0.0, 1.0));
    _average += (value - _average) * .08;
  }

  void decay(double dt) {
    kick *= math.pow(.002, dt).toDouble();
    _quietFor += dt;
  }
}
