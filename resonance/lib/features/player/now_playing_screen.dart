import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(playbackStateProvider).valueOrNull ??
        const ResonancePlaybackState();
    final track = state.currentTrack ?? demoTrack;
    final next = _nextTrack(state);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _Header(current: track, next: next),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  if (compact) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
                      child: Column(
                        children: [
                          TrackArtwork(
                            track: track,
                            size: min(constraints.maxWidth - 44, 430),
                            borderRadius: 2,
                            fallbackAsset:
                                'assets/images/resonance_fallback_cover.png',
                          ),
                          const SizedBox(height: 30),
                          _Details(state: state, track: track, desktop: false),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(54, 34, 64, 42),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 9,
                          child: LayoutBuilder(
                            builder: (context, artworkConstraints) {
                              final size = min(
                                artworkConstraints.maxWidth,
                                artworkConstraints.maxHeight,
                              );
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: TrackArtwork(
                                  track: track,
                                  size: size,
                                  borderRadius: 2,
                                  fallbackAsset:
                                      'assets/images/resonance_fallback_cover.png',
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 66),
                        Expanded(
                          flex: 11,
                          child: _Details(
                            state: state,
                            track: track,
                            desktop: true,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  UnifiedTrack? _nextTrack(ResonancePlaybackState state) {
    if (state.queue.isEmpty || state.currentIndex < 0) return null;
    final index = state.currentIndex + 1;
    if (index < state.queue.length) return state.queue[index];
    return state.repeatMode == PlaybackRepeatMode.all
        ? state.queue.first
        : null;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.current, required this.next});

  final UnifiedTrack current;
  final UnifiedTrack? next;

  @override
  Widget build(BuildContext context) {
    final label = next == null
        ? 'Далее: —'
        : 'Далее: ${next!.title} — ${next!.artist}';
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF292724))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Назад',
            onPressed: context.pop,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          const Text(
            'RESONANCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFBBB7B0),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 24),
          ProviderBadge(
            provider:
                current.preferredProvider ?? current.sources.first.provider,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({
    required this.state,
    required this.track,
    required this.desktop,
  });

  final ResonancePlaybackState state;
  final UnifiedTrack track;
  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallbackDuration = track.duration ?? const Duration(seconds: 1);
    final duration = state.duration > Duration.zero
        ? state.duration
        : fallbackDuration;
    final maxMs = max(1, duration.inMilliseconds);
    final positionMs = state.position.inMilliseconds.clamp(0, maxMs);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFFF3EFE7),
            fontSize: desktop ? 64 : 40,
            height: 0.94,
            letterSpacing: desktop ? -3.6 : -2.2,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF9B9690),
            fontSize: desktop ? 20 : 17,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: desktop ? 58 : 38),
        _Waveform(
          value: positionMs / maxMs,
          activeColor: Theme.of(context).colorScheme.primary,
          onSeek: (value) => unawaited(
            ref
                .read(playbackServiceProvider.future)
                .then(
                  (service) => service.seek(
                    Duration(milliseconds: (maxMs * value).round()),
                  ),
                ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(_time(state.position)), Text(_time(duration))],
        ),
        SizedBox(height: desktop ? 34 : 26),
        _Controls(state: state, desktop: desktop),
      ],
    );
  }

  String _time(Duration value) {
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${value.inMinutes}:$seconds';
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.state, required this.desktop});

  final ResonancePlaybackState state;
  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> run(FutureOr<void> Function(dynamic) action) async {
      final service = await ref.read(playbackServiceProvider.future);
      await action(service);
    }

    return Row(
      children: [
        _Control(
          tooltip: 'Перемешать',
          icon: Icons.shuffle_rounded,
          active: state.shuffle,
          onPressed: () =>
              unawaited(run((service) => service.setShuffle(!state.shuffle))),
        ),
        const Spacer(),
        _Control(
          tooltip: 'Предыдущий',
          icon: Icons.skip_previous_rounded,
          size: desktop ? 38 : 34,
          onPressed: () => unawaited(run((service) => service.previous())),
        ),
        SizedBox(width: desktop ? 22 : 12),
        IconButton.filled(
          tooltip: state.playing ? 'Пауза' : 'Воспроизвести',
          iconSize: desktop ? 38 : 34,
          padding: EdgeInsets.all(desktop ? 18 : 15),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: const Color(0xFF080706),
          ),
          onPressed: () => unawaited(
            run((service) {
              if (state.currentTrack == null) {
                return service.playTrack(demoTrack);
              }
              return state.playing ? service.pause() : service.play();
            }),
          ),
          icon: state.buffering
              ? const SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF080706),
                  ),
                )
              : Icon(
                  state.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
        ),
        SizedBox(width: desktop ? 22 : 12),
        _Control(
          tooltip: 'Следующий',
          icon: Icons.skip_next_rounded,
          size: desktop ? 38 : 34,
          onPressed: () => unawaited(run((service) => service.next())),
        ),
        const Spacer(),
        _Control(
          tooltip: 'Повтор',
          icon: state.repeatMode == PlaybackRepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          active: state.repeatMode != PlaybackRepeatMode.off,
          onPressed: () => unawaited(
            run(
              (service) => service.setRepeatMode(switch (state.repeatMode) {
                PlaybackRepeatMode.off => PlaybackRepeatMode.all,
                PlaybackRepeatMode.all => PlaybackRepeatMode.one,
                PlaybackRepeatMode.one => PlaybackRepeatMode.off,
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.size = 26,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: size,
      color: active
          ? Theme.of(context).colorScheme.primary
          : const Color(0xFFD4D0C9),
      icon: Icon(icon),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.value,
    required this.activeColor,
    required this.onSeek,
  });

  final double value;
  final Color activeColor;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void seek(Offset point) =>
            onSeek((point.dx / constraints.maxWidth).clamp(0, 1));
        return Semantics(
          slider: true,
          label: 'Позиция воспроизведения',
          value: '${(value * 100).round()}%',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => seek(details.localPosition),
            onHorizontalDragUpdate: (details) => seek(details.localPosition),
            child: SizedBox(
              height: 72,
              width: double.infinity,
              child: CustomPaint(painter: _WaveformPainter(value, activeColor)),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter(this.value, this.activeColor);

  final double value;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 74;
    const gap = 3.0;
    final width = (size.width - gap * (bars - 1)) / bars;
    final played = Paint()..color = activeColor;
    final remaining = Paint()..color = const Color(0xFF3A3733);

    for (var index = 0; index < bars; index++) {
      final wave =
          0.25 +
          0.75 *
              (sin(index * 0.71).abs() * 0.58 +
                  sin(index * 0.17 + 1.4).abs() * 0.42);
      final height = max(7.0, wave * size.height);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          index * (width + gap),
          (size.height - height) / 2,
          width,
          height,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, index / (bars - 1) <= value ? played : remaining);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.activeColor != activeColor;
}
