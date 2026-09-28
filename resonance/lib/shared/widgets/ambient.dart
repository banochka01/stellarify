import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/shared/widgets/playback_position.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

/// Цвета, извлечённые из обложки: ими подсвечиваются Stage, плеер и главная.
@immutable
class TrackPalette {
  const TrackPalette({
    required this.glow,
    required this.shadow,
    required this.accent,
  });

  /// Детерминированная палитра без загрузки изображения.
  factory TrackPalette.fallback(UnifiedTrack track) {
    final colors = ArtworkFallback.gradientFor(track);
    return TrackPalette(
      glow: colors.first,
      shadow: colors.last,
      accent: Color.lerp(colors.first, const Color(0xFFFFE2C9), .35)!,
    );
  }

  /// Основное тёплое свечение (верхний левый угол сцены).
  final Color glow;

  /// Глубокий тон для второго пятна и нижней части фона.
  final Color shadow;

  /// Светлый акцент для прогресса и активных элементов поверх фона.
  final Color accent;

  static TrackPalette lerp(TrackPalette a, TrackPalette b, double t) =>
      TrackPalette(
        glow: Color.lerp(a.glow, b.glow, t)!,
        shadow: Color.lerp(a.shadow, b.shadow, t)!,
        accent: Color.lerp(a.accent, b.accent, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is TrackPalette &&
      other.glow == glow &&
      other.shadow == shadow &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(glow, shadow, accent);
}

/// Палитра обложки. Ключ — URL, чтобы одинаковые обложки не считались дважды.
final trackPaletteProvider = FutureProvider.autoDispose
    .family<TrackPalette?, String>((ref, artworkUrl) async {
      ref.keepAlive();
      try {
        final scheme = await ColorScheme.fromImageProvider(
          provider: ResizeImage(
            NetworkImage(artworkUrl),
            width: 96,
            height: 96,
          ),
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ).timeout(const Duration(seconds: 6));
        return TrackPalette(
          glow: scheme.primaryContainer,
          shadow: scheme.tertiaryContainer,
          accent: scheme.primary,
        );
      } on Object {
        return null;
      }
    });

TrackPalette watchTrackPalette(WidgetRef ref, UnifiedTrack track) {
  final artwork = track.artworkUrl;
  if (artwork == null) return TrackPalette.fallback(track);
  return ref
          .watch(
            trackPaletteProvider(
              highQualityArtworkUrl(artwork, targetSize: 400),
            ),
          )
          .valueOrNull ??
      TrackPalette.fallback(track);
}

/// Тёплый ambient-фон по палитре трека: два мягких пятна света на почти
/// чёрной основе. Цвета плавно перетекают при смене трека.
class AmbientBackdrop extends ConsumerWidget {
  const AmbientBackdrop({
    required this.track,
    this.intensity = 1,
    this.base = const Color(0xFF0A0807),
    super.key,
  });

  final UnifiedTrack track;
  final double intensity;
  final Color base;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchTrackPalette(ref, track);
    // Фон перерисовывается только при смене палитры, а не вместе с
    // прогрессом и текстом поверх него.
    return RepaintBoundary(
      child: TweenAnimationBuilder<TrackPalette>(
        tween: _PaletteTween(end: palette),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : ResonanceMotion.gentle * 2,
        curve: ResonanceMotion.curve,
        builder: (context, value, _) => DecoratedBox(
          decoration: BoxDecoration(color: base),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-.75, -.85),
                    radius: 1.25,
                    colors: [
                      value.glow.withValues(alpha: .42 * intensity),
                      value.glow.withValues(alpha: .10 * intensity),
                      Colors.transparent,
                    ],
                    stops: const [0, .45, 1],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(.85, .95),
                    radius: 1.1,
                    colors: [
                      value.shadow.withValues(alpha: .30 * intensity),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(.9, -.55),
                    radius: .8,
                    colors: [
                      value.accent.withValues(alpha: .10 * intensity),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Мягкая виньетка собирает взгляд к центру и прячет края.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.2,
                    colors: [Colors.transparent, Color(0x66000000)],
                    stops: [.55, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteTween extends Tween<TrackPalette> {
  _PaletteTween({required TrackPalette end}) : super(begin: end, end: end);

  @override
  TrackPalette lerp(double t) => TrackPalette.lerp(begin!, end!, t);
}

//// Круглая «стеклянная» кнопка управления из концептов 2026-09.
class RoundControl extends StatelessWidget {
  const RoundControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.size = 52,
    this.activeColor = const Color(0xFFFF8A5B),
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final double size;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final duration = ResonanceMotion.durationOf(
      context,
      ResonanceMotion.standard,
    );
    return Tooltip(
      message: tooltip,
      child: ResonancePressable(
        enabled: onPressed != null,
        child: AnimatedContainer(
          duration: duration,
          curve: ResonanceMotion.curve,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: active
                  ? [
                      activeColor.withValues(alpha: .26),
                      activeColor.withValues(alpha: .10),
                    ]
                  : const [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
            ),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: .6)
                  : const Color(0x26FFFFFF),
            ),
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: active ? .22 : 0),
                blurRadius: 22,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: ResonanceMotion.curve,
                  switchOutCurve: ResonanceMotion.exitCurve,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: .7, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Icon(
                    icon,
                    key: ValueKey(icon),
                    size: size * .42,
                    color: active ? activeColor : const Color(0xFFEDE7DE),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Главная кнопка воспроизведения: кремовый круг с мягким свечением.
class CreamPlayButton extends StatelessWidget {
  const CreamPlayButton({
    required this.playing,
    required this.onPressed,
    this.buffering = false,
    this.size = 68,
    super.key,
  });

  final bool playing;
  final bool buffering;
  final double size;
  final VoidCallback? onPressed;

  static const cream = Color(0xFFF1ECE2);
  static const ink = Color(0xFF14110F);

  @override
  Widget build(BuildContext context) {
    final duration = ResonanceMotion.durationOf(
      context,
      ResonanceMotion.standard,
    );
    final Widget glyph = buffering
        ? SizedBox.square(
            key: const ValueKey('buffering'),
            dimension: size * .36,
            child: const CircularProgressIndicator(
              strokeWidth: 2.2,
              color: ink,
            ),
          )
        : Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(playing),
            size: size * .46,
            color: ink,
          );
    return Tooltip(
      message: playing ? 'Пауза' : 'Воспроизвести',
      child: ResonancePressable(
        pressedScale: .94,
        hoverScale: 1.03,
        child: AnimatedContainer(
          duration: duration,
          curve: ResonanceMotion.curve,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: cream.withValues(alpha: playing ? .34 : .18),
                blurRadius: playing ? 38 : 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            color: cream,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: ResonanceMotion.curve,
                  switchOutCurve: ResonanceMotion.exitCurve,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: .6, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: glyph,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Тонкая линия прогресса с тёплым градиентом, как в концептах.
///
/// Позицию берёт сама из плеера и двигается плавно, кадр за кадром. Перемотка
/// отправляется один раз — когда палец или мышь отпущены.
class AmbientProgress extends StatefulWidget {
  const AmbientProgress({
    required this.duration,
    required this.onSeek,
    this.accent = const Color(0xFFFF8A5B),
    this.showTimes = true,
    super.key,
  });

  /// Длительность из метаданных трека, пока движок её не сообщил.
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color accent;
  final bool showTimes;

  @override
  State<AmbientProgress> createState() => _AmbientProgressState();
}

class _AmbientProgressState extends State<AmbientProgress> {
  double? _drag;
  bool _hovered = false;

  /// После отпускания держим выбранную точку, пока движок не догонит её.
  Duration? _pendingSeek;

  static String _time(Duration value) =>
      '${value.inMinutes}:${value.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => SmoothPlaybackPosition(
    fallbackDuration: widget.duration,
    builder: (context, position, duration) {
      final total = duration.inMilliseconds;
      final pending = _pendingSeek;
      if (pending != null && (position - pending).inMilliseconds.abs() < 900) {
        _pendingSeek = null;
      }
      final effective = _pendingSeek ?? position;
      final fraction =
          _drag ??
          (total <= 0
              ? 0.0
              : (effective.inMilliseconds / total).clamp(0.0, 1.0));
      final shown = _drag == null
          ? effective
          : Duration(milliseconds: (total * _drag!).round());
      final bar = _bar(context, fraction, total, shown);
      if (!widget.showTimes) return bar;
      const times = TextStyle(
        color: Color(0xFF9D968E),
        fontSize: 11,
        fontWeight: FontWeight.w500,
        fontFeatures: [FontFeature.tabularFigures()],
      );
      return Row(
        children: [
          SizedBox(width: 38, child: Text(_time(shown), style: times)),
          const SizedBox(width: 8),
          Expanded(child: bar),
          const SizedBox(width: 8),
          SizedBox(
            width: 38,
            child: Text(
              _time(duration),
              style: times,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      );
    },
  );

  Widget _bar(
    BuildContext context,
    double fraction,
    int total,
    Duration shown,
  ) {
    final active = _drag != null || _hovered;
    final duration = ResonanceMotion.durationOf(context, ResonanceMotion.quick);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double at(Offset point) => (point.dx / width).clamp(0.0, 1.0);
        void commit() {
          final value = _drag;
          if (value == null || total <= 0) return;
          final target = Duration(milliseconds: (total * value).round());
          setState(() {
            _drag = null;
            _pendingSeek = target;
          });
          widget.onSeek(target);
          // Если перемотка не удалась, не держим ползунок в чужой точке.
          Future<void>.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && _pendingSeek == target) {
              setState(() => _pendingSeek = null);
            }
          });
        }

        final thickness = active ? 5.0 : 3.0;
        return Semantics(
          slider: true,
          label: 'Позиция воспроизведения',
          value: _time(shown),
          child: MouseRegion(
            cursor: total > 0 ? SystemMouseCursors.click : MouseCursor.defer,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: total <= 0
                  ? null
                  : (details) =>
                        setState(() => _drag = at(details.localPosition)),
              onTapUp: total <= 0 ? null : (_) => commit(),
              onHorizontalDragStart: total <= 0
                  ? null
                  : (details) =>
                        setState(() => _drag = at(details.localPosition)),
              onHorizontalDragUpdate: total <= 0
                  ? null
                  : (details) =>
                        setState(() => _drag = at(details.localPosition)),
              onHorizontalDragEnd: total <= 0 ? null : (_) => commit(),
              onHorizontalDragCancel: () => setState(() => _drag = null),
              child: SizedBox(
                height: 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedContainer(
                      duration: duration,
                      curve: ResonanceMotion.curve,
                      height: thickness,
                      decoration: BoxDecoration(
                        color: const Color(0x2EFFFFFF),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    // Ширина меняется каждый кадр — без анимации, иначе
                    // заливка отстаёт от ползунка.
                    Container(
                      height: thickness,
                      width: width * fraction,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: LinearGradient(
                          colors: [const Color(0xFFFF5A36), widget.accent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accent.withValues(alpha: .35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: width * fraction - 7,
                      child: AnimatedScale(
                        duration: duration,
                        curve: ResonanceMotion.curve,
                        scale: active ? 1 : 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F2E9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.accent.withValues(alpha: .55),
                                blurRadius: 12,
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

// Запускает действие без ожидания и гасит ошибку, чтобы жест не падал.
void fireAndForget(Future<void> Function() action) =>
    unawaited(action().catchError((Object _) {}));
