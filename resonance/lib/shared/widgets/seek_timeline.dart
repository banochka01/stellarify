import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';

/// Полоса перемотки нижнего плеера. Во время перетаскивания показывает точку
/// под пальцем, а [onSeek] вызывает один раз — при отпускании.
class SeekTimeline extends StatefulWidget {
  const SeekTimeline({
    required this.value,
    required this.onSeek,
    this.height = 18,
    super.key,
  });

  final double value;
  final ValueChanged<double> onSeek;
  final double height;

  @override
  State<SeekTimeline> createState() => _SeekTimelineState();
}

class _SeekTimelineState extends State<SeekTimeline> {
  double? _drag;
  double? _pending;
  bool _hovered = false;

  void _commit() {
    final value = _drag;
    if (value == null) return;
    setState(() {
      _drag = null;
      _pending = value;
    });
    widget.onSeek(value);
    // Если перемотка не удалась, не держим ползунок в чужой точке вечно.
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _pending == value) setState(() => _pending = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    if (pending != null && (widget.value - pending).abs() < .01) {
      _pending = null;
    }
    final safeValue = (_drag ?? _pending ?? widget.value).clamp(0.0, 1.0);
    final colors = Theme.of(context).colorScheme;
    final active = _drag != null || _hovered;
    final duration = ResonanceMotion.durationOf(context, ResonanceMotion.quick);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double at(Offset position) => (position.dx / width).clamp(0.0, 1.0);
        return Semantics(
          slider: true,
          label: 'Позиция воспроизведения',
          value: '${(safeValue * 100).round()}%',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  setState(() => _drag = at(details.localPosition)),
              onTapUp: (_) => _commit(),
              onHorizontalDragStart: (details) =>
                  setState(() => _drag = at(details.localPosition)),
              onHorizontalDragUpdate: (details) =>
                  setState(() => _drag = at(details.localPosition)),
              onHorizontalDragEnd: (_) => _commit(),
              onHorizontalDragCancel: () => setState(() => _drag = null),
              child: SizedBox(
                height: widget.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          progress: safeValue,
                          active: active,
                          played: colors.primary,
                          rest: colors.outline,
                        ),
                      ),
                    ),
                    Positioned(
                      left: width * safeValue - 6,
                      child: AnimatedScale(
                        duration: duration,
                        curve: ResonanceMotion.curve,
                        scale: active ? 1 : 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EBF5),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: .5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Прогресс как волновая форма: столбики с детерминированной высотой,
/// сыгранная часть — акцентом. Высоты стабильны между кадрами.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progress,
    required this.active,
    required this.played,
    required this.rest,
  });

  final double progress;
  final bool active;
  final Color played;
  final Color rest;

  static double _height(int i) {
    final noise = ((i * 7919 + 104729) % 997) / 997;
    final swell = (math.sin(i * .31) + 1) / 2;
    return .28 + swell * .42 + noise * .3;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const step = 4.0;
    const bar = 2.2;
    final count = (size.width / step).floor();
    if (count <= 0) return;
    final scale = active ? 1.0 : .78;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final x = i * step + bar / 2;
      final h = size.height * _height(i) * scale;
      paint
        ..color = x / size.width <= progress ? played : rest
        ..strokeWidth = bar;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.active != active ||
      old.played != played ||
      old.rest != rest;
}
