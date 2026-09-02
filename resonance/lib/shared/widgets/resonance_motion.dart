import 'package:flutter/material.dart';

abstract final class ResonanceMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const entrance = Duration(milliseconds: 280);
  static const curve = Curves.easeOutCubic;
}

class ResonanceEntrance extends StatefulWidget {
  const ResonanceEntrance({
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, .035),
    super.key,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<ResonanceEntrance> createState() => _ResonanceEntranceState();
}

class _ResonanceEntranceState extends State<ResonanceEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ResonanceMotion.entrance,
  );
  late Animation<double> _opacity;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _rebuildAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.delay > Duration.zero) {
        await Future<void>.delayed(widget.delay);
      }
      if (mounted) {
        await _controller.forward();
      }
    });
  }

  void _rebuildAnimations() {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: ResonanceMotion.curve,
    );
    _opacity = curved;
    _position = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _position, child: widget.child),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class ResonanceAnimatedSwap extends StatelessWidget {
  const ResonanceAnimatedSwap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : ResonanceMotion.standard,
      reverseDuration: reduced ? Duration.zero : ResonanceMotion.quick,
      switchInCurve: ResonanceMotion.curve,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .035),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
