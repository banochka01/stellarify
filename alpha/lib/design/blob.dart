import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
    super.key,
  });

  final Color color;

  /// 0 — asleep, 1 — playing loud.
  final double energy;
  final String? label;
  final double labelSize;

  @override
  State<LivingBlob> createState() => _LivingBlobState();
}

class _LivingBlobState extends State<LivingBlob>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  double _energy = 0;
  Duration _last = Duration.zero;

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
    _time.value += dt * (.35 + _energy * .9);
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
    required this.label,
    required this.labelSize,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final Color color;
  final double Function() energy;
  final String? label;
  final double labelSize;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final e = energy();
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .34;

    // Halo: a wide, blurred copy of the shape.
    final halo = _shape(center, radius * 1.18, t * .7, .1 + e * .08);
    canvas.drawPath(
      halo,
      Paint()
        ..color = color.withValues(alpha: .08 + e * .08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );

    // Ghost outlines trailing behind the mass.
    for (var i = 3; i >= 1; i--) {
      final ring = _shape(
        center,
        radius * (1 + i * .07),
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

    final body = _shape(center, radius, t, .09 + e * .13);
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
