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
    final thickness = active ? 5.0 : 3.0;
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
                    AnimatedContainer(
                      duration: duration,
                      curve: ResonanceMotion.curve,
                      height: thickness,
                      color: colors.outline.withValues(alpha: .7),
                    ),
                    Container(
                      height: thickness,
                      width: width * safeValue,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFFFF5A36), colors.primary],
                        ),
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(99),
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
                            color: const Color(0xFFF7F2E9),
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
