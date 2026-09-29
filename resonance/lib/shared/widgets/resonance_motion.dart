import 'package:flutter/material.dart';

abstract final class ResonanceMotion {
  static const instant = Duration(milliseconds: 90);
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const entrance = Duration(milliseconds: 300);
  static const gentle = Duration(milliseconds: 380);
  static const curve = Cubic(.16, 1, .3, 1);
  static const exitCurve = Cubic(.4, 0, 1, 1);

  static Duration durationOf(BuildContext context, Duration duration) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false
      ? Duration.zero
      : duration;
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
  const ResonanceAnimatedSwap({
    required this.child,
    this.alignment = Alignment.center,
    super.key,
  });

  final Widget child;

  /// Как выравнивать старый и новый вариант друг относительно друга. Для
  /// текста, прижатого к краю, нужен край — иначе на время перехода более
  /// узкая строка съезжает к центру, а в конце прыгает обратно.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : ResonanceMotion.standard,
      reverseDuration: reduced ? Duration.zero : ResonanceMotion.quick,
      switchInCurve: ResonanceMotion.curve,
      switchOutCurve: ResonanceMotion.exitCurve,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: alignment,
        children: [...previousChildren, ?currentChild],
      ),
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

class ResonanceTrackSwap extends StatelessWidget {
  const ResonanceTrackSwap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : ResonanceMotion.gentle,
      reverseDuration: reduced ? Duration.zero : ResonanceMotion.quick,
      switchInCurve: ResonanceMotion.curve,
      switchOutCurve: ResonanceMotion.exitCurve,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: .985, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Мягкая смена полноэкранного фона: без сдвига, старый кадр гаснет медленно,
/// поэтому между обложками не мелькает пустота.
class ResonanceCrossfade extends StatelessWidget {
  const ResonanceCrossfade({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduced ? Duration.zero : ResonanceMotion.gentle * 2;
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: duration,
        reverseDuration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          children: [...previousChildren, ?currentChild],
        ),
        child: child,
      ),
    );
  }
}

/// Adds the same subtle hover lift and tactile press response to interactive
/// surfaces on mouse, touch, and stylus clients without taking over their tap
/// semantics. The wrapped control remains responsible for its own action,
/// focus, ripple, and disabled state.
class ResonancePressable extends StatefulWidget {
  const ResonancePressable({
    required this.child,
    this.enabled = true,
    this.hoverScale = 1.006,
    this.pressedScale = .982,
    this.hoverOffset = const Offset(0, -.012),
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double hoverScale;
  final double pressedScale;
  final Offset hoverOffset;

  @override
  State<ResonancePressable> createState() => _ResonancePressableState();
}

class _ResonancePressableState extends State<ResonancePressable> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (!widget.enabled || _hovered == value) return;
    setState(() {
      _hovered = value;
      if (!value) _pressed = false;
    });
  }

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(ResonancePressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && (_hovered || _pressed)) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduced ? Duration.zero : ResonanceMotion.quick;
    final scale = _pressed
        ? widget.pressedScale
        : _hovered
        ? widget.hoverScale
        : 1.0;
    final offset = _hovered && !_pressed ? widget.hoverOffset : Offset.zero;

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedSlide(
          duration: duration,
          curve: ResonanceMotion.curve,
          offset: offset,
          child: AnimatedScale(
            duration: duration,
            curve: ResonanceMotion.curve,
            scale: scale,
            child: RepaintBoundary(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Контейнер вкладок: все посещённые ветки остаются построенными, а смена
/// вкладки — одновременный кроссфейд уходящей и входящей с лёгким сдвигом.
/// Неактивные ветки выключены из тикеров, хит-теста и отрисовки.
class ResonanceBranchStack extends StatefulWidget {
  const ResonanceBranchStack({
    required this.index,
    required this.children,
    super.key,
  });

  final int index;
  final List<Widget> children;

  @override
  State<ResonanceBranchStack> createState() => _ResonanceBranchStackState();
}

class _ResonanceBranchStackState extends State<ResonanceBranchStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late int _current = widget.index;
  int? _previous;
  int _direction = 1;

  @override
  void didUpdateWidget(ResonanceBranchStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _current) {
      _direction = widget.index > _current ? 1 : -1;
      _previous = _current;
      _current = widget.index;
      _controller.forward(from: 0).whenCompleteOrCancel(() {
        if (mounted) setState(() => _previous = null);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = reduced ? 1.0 : _controller.value;
        final enter = ResonanceMotion.curve.transform(t);
        final exit = Curves.easeOutCubic.transform((t / .7).clamp(0.0, 1.0));
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _branch(
                i,
                visible: i == _current || (i == _previous && t < 1),
                opacity: i == _current ? enter : 1 - exit,
                dx: i == _current
                    ? 14.0 * _direction * (1 - enter)
                    : -10.0 * _direction * exit,
              ),
          ],
        );
      },
    );
  }

  Widget _branch(
    int i, {
    required bool visible,
    required double opacity,
    required double dx,
  }) {
    final active = i == _current;
    return Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: !active,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: RepaintBoundary(
                child: KeyedSubtree(
                  key: ValueKey('branch-$i'),
                  child: widget.children[i],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
