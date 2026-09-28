import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/unified_track.dart';
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
    return TweenAnimationBuilder<TrackPalette>(
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
          ],
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

/// Круглая «стеклянная» кнопка управления из концептов 2026-09.
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
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: ResonancePressable(
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: active
              ? activeColor.withValues(alpha: .16)
              : const Color(0x14FFFFFF),
          shape: CircleBorder(
            side: BorderSide(
              color: active
                  ? activeColor.withValues(alpha: .55)
                  : const Color(0x24FFFFFF),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(
              icon,
              size: size * .42,
              color: active ? activeColor : const Color(0xFFEDE7DE),
            ),
          ),
        ),
      ),
    ),
  );
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

  @override
  Widget build(BuildContext context) => Tooltip(
    message: playing ? 'Пауза' : 'Воспроизвести',
    child: ResonancePressable(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x40F1ECE2),
              blurRadius: 32,
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
              child: buffering
                  ? SizedBox.square(
                      dimension: size * .36,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF14110F),
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: ResonanceMotion.quick,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey(playing),
                        size: size * .46,
                        color: const Color(0xFF14110F),
                      ),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Тонкая линия прогресса с тёплым градиентом, как в концептах.
class AmbientProgress extends StatefulWidget {
  const AmbientProgress({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.accent = const Color(0xFFFF8A5B),
    this.showTimes = true,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color accent;
  final bool showTimes;

  @override
  State<AmbientProgress> createState() => _AmbientProgressState();
}

class _AmbientProgressState extends State<AmbientProgress> {
  double? _drag;

  static String _time(Duration value) =>
      '${value.inMinutes}:${value.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds;
    final fraction =
        _drag ??
        (total <= 0
            ? 0.0
            : (widget.position.inMilliseconds / total).clamp(0.0, 1.0));
    final times = const TextStyle(
      color: Color(0xFF9D968E),
      fontSize: 11,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    final bar = LayoutBuilder(
      builder: (context, constraints) {
        double at(Offset point) =>
            (point.dx / constraints.maxWidth).clamp(0.0, 1.0);
        void commit() {
          final value = _drag;
          if (value == null || total <= 0) return;
          setState(() => _drag = null);
          widget.onSeek(Duration(milliseconds: (total * value).round()));
        }

        return Semantics(
          slider: true,
          label: 'Позиция воспроизведения',
          value: _time(widget.position),
          child: MouseRegion(
            cursor: total > 0 ? SystemMouseCursors.click : MouseCursor.defer,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: total <= 0
                  ? null
                  : (details) =>
                        setState(() => _drag = at(details.localPosition)),
              onTapUp: total <= 0 ? null : (_) => commit(),
              onHorizontalDragUpdate: total <= 0
                  ? null
                  : (details) =>
                        setState(() => _drag = at(details.localPosition)),
              onHorizontalDragEnd: total <= 0 ? null : (_) => commit(),
              child: SizedBox(
                height: 22,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: _drag == null ? 3 : 5,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Color(0x2EFFFFFF)),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: fraction,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFF5A36),
                                    widget.accent,
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
              ),
            ),
          ),
        );
      },
    );
    if (!widget.showTimes) return bar;
    final shown = _drag == null
        ? widget.position
        : Duration(milliseconds: (total * _drag!).round());
    return Row(
      children: [
        Text(_time(shown), style: times),
        const SizedBox(width: 12),
        Expanded(child: bar),
        const SizedBox(width: 12),
        Text(_time(widget.duration), style: times),
      ],
    );
  }
}

/// Запускает действие без ожидания и гасит ошибку, чтобы жест не падал.
void fireAndForget(Future<void> Function() action) =>
    unawaited(action().catchError((Object _) {}));
