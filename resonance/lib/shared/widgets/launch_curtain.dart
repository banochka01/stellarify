import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/resonance_logo.dart';

/// Короткая заставка запуска: знак проявляется, от него расходится одна
/// звуковая волна, затем шторка растворяется, а интерфейс чуть поднимается.
/// Вся последовательность занимает ~1.1 с и не держит загрузку: приложение
/// под шторкой уже строится. При «уменьшении движения» показывается только
/// короткий fade.
class LaunchCurtain extends StatefulWidget {
  const LaunchCurtain({required this.child, super.key});

  final Widget child;

  @override
  State<LaunchCurtain> createState() => _LaunchCurtainState();
}

class _LaunchCurtainState extends State<LaunchCurtain>
    with SingleTickerProviderStateMixin {
  static final bool _skip = Platform.environment.containsKey('FLUTTER_TEST');

  late final AnimationController _controller;
  bool _done = _skip;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    if (_skip) return;
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _controller.duration = const Duration(milliseconds: 240);
      }
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    const curve = Cubic(.16, 1, .3, 1);
    final mark = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .45, curve: curve),
    );
    final ring = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.18, .8, curve: Curves.easeOutCubic),
    );
    final exit = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.62, 1, curve: Curves.easeInOutCubic),
    );
    final background =
        Theme.of(context).extension<ResonanceTokens>()?.background ??
        context.tokens.background;
    final accent = Theme.of(context).colorScheme.primary;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: exit,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 12 * (1 - exit.value)),
            child: Opacity(opacity: exit.value, child: child),
          ),
          child: widget.child,
        ),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Opacity(
              opacity: 1 - exit.value,
              child: ColoredBox(
                color: background,
                child: Center(
                  child: SizedBox.square(
                    dimension: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size.square(220),
                          painter: _RingPainter(
                            progress: ring.value,
                            color: accent,
                          ),
                        ),
                        Opacity(
                          opacity: mark.value,
                          child: Transform.scale(
                            scale: .86 + .14 * mark.value,
                            child: const ResonanceLogo(size: 72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    // Две волны со сдвигом: как отклик струны, а не пульсирующий маяк.
    for (final offset in const [0.0, .22]) {
      final t = ((progress - offset) / (1 - offset)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final radius = 40 + (maxRadius - 40) * t;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: .55 * math.pow(1 - t, 1.4));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
