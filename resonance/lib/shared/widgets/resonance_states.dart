import 'dart:async';

import 'package:flutter/material.dart';
import 'package:resonance/shared/theme/resonance_tokens.dart';

/// Shimmering placeholder block. Respects "reduce motion": the shimmer is
/// replaced by a static tone when animations are disabled.
class ResonanceSkeleton extends StatefulWidget {
  const ResonanceSkeleton({
    this.width,
    this.height = 14,
    this.radius = ResonanceRadii.xs,
    super.key,
  });

  const ResonanceSkeleton.circle({required double size, super.key})
    : width = size,
      height = size,
      radius = ResonanceRadii.pill;

  final double? width;
  final double height;
  final double radius;

  @override
  State<ResonanceSkeleton> createState() => _ResonanceSkeletonState();
}

class _ResonanceSkeletonState extends State<ResonanceSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced || !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
    } else if (!_started) {
      _started = true;
      // Finite so pumpAndSettle and idle screens never spin forever.
      unawaited(_controller.repeat(count: 12).orCancel.catchError((_) {}));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ResonanceTokens.of(context);
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final box = SizedBox(width: widget.width, height: widget.height);
    if (reduced) {
      return Semantics(
        label: 'Загрузка',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.skeletonBase,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          child: box,
        ),
      );
    }
    return Semantics(
      label: 'Загрузка',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 3 - 1;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(t - 1, 0),
                end: Alignment(t + 1, 0),
                colors: [
                  tokens.skeletonBase,
                  tokens.skeletonHighlight,
                  tokens.skeletonBase,
                ],
              ),
            ),
            child: child,
          );
        },
        child: box,
      ),
    );
  }
}

/// Skeleton shaped like a track row (artwork + two lines).
class ResonanceTrackRowSkeleton extends StatelessWidget {
  const ResonanceTrackRowSkeleton({this.artworkSize = 48, super.key});

  final double artworkSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ResonanceSpacing.sm),
      child: Row(
        children: [
          ResonanceSkeleton(
            width: artworkSize,
            height: artworkSize,
            radius: ResonanceRadii.sm,
          ),
          const SizedBox(width: ResonanceSpacing.md),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResonanceSkeleton(
                    width: constraints.maxWidth * .62,
                    height: 13,
                  ),
                  const SizedBox(height: ResonanceSpacing.sm),
                  ResonanceSkeleton(
                    width: constraints.maxWidth * .38,
                    height: 11,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A list of [count] track-row skeletons.
class ResonanceTrackListSkeleton extends StatelessWidget {
  const ResonanceTrackListSkeleton({this.count = 5, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('resonance-track-list-skeleton'),
      children: [
        for (var i = 0; i < count; i++) const ResonanceTrackRowSkeleton(),
      ],
    );
  }
}

/// Friendly empty / error state with icon, title, hint and optional action.
class ResonanceEmptyState extends StatelessWidget {
  const ResonanceEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
    this.tone,
    super.key,
  });

  const ResonanceEmptyState.error({
    required String title,
    String? message,
    Widget? action,
    bool compact = false,
    Key? key,
  }) : this(
         icon: Icons.error_outline_rounded,
         title: title,
         message: message,
         action: action,
         compact: compact,
         tone: const Color(0xFFFF7A6B),
         key: key,
       );

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final tokens = ResonanceTokens.of(context);
    final accent = tone ?? tokens.accent;
    final badge = Container(
      width: compact ? 44 : 64,
      height: compact ? 44 : 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accent.withValues(alpha: .22),
            accent.withValues(alpha: .04),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: .28)),
      ),
      child: Icon(icon, size: compact ? 22 : 30, color: accent),
    );
    final texts = Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: ResonanceType.subtitle.copyWith(color: tokens.text),
        ),
        if (message != null) ...[
          const SizedBox(height: ResonanceSpacing.xs),
          Text(
            message!,
            textAlign: compact ? TextAlign.start : TextAlign.center,
            style: ResonanceType.body.copyWith(color: tokens.textMuted),
          ),
        ],
      ],
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? ResonanceSpacing.lg + 4 : 28),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: .86),
        borderRadius: ResonanceRadii.card,
        border: Border.all(color: tokens.border),
      ),
      child: compact
          ? Row(
              children: [
                badge,
                const SizedBox(width: ResonanceSpacing.lg),
                Expanded(child: texts),
                if (action != null) ...[
                  const SizedBox(width: ResonanceSpacing.md),
                  action!,
                ],
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                badge,
                const SizedBox(height: ResonanceSpacing.lg),
                texts,
                if (action != null) ...[
                  const SizedBox(height: ResonanceSpacing.lg),
                  action!,
                ],
              ],
            ),
    );
  }
}

/// Standard 5.0 card surface: tokenised radius, border, subtle elevation,
/// optional tap with hover highlight.
class ResonanceSurfaceCard extends StatelessWidget {
  const ResonanceSurfaceCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(ResonanceSpacing.lg),
    this.elevated = false,
    this.accent,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  /// Optional tint applied as a soft top-left gradient.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tokens = ResonanceTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: ResonanceRadii.card,
        boxShadow: elevated ? ResonanceShadows.medium : ResonanceShadows.none,
      ),
      child: Material(
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: ResonanceRadii.card,
          side: BorderSide(color: tokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: accent == null
              ? null
              : BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent!.withValues(alpha: .16),
                      accent!.withValues(alpha: 0),
                    ],
                  ),
                ),
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Small uppercase section label used across screens.
class ResonanceSectionLabel extends StatelessWidget {
  const ResonanceSectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = ResonanceTokens.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ResonanceType.overline.copyWith(color: tokens.textMuted),
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}
