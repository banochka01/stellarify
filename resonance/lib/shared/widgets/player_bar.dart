import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/artist/artist_screen.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/ambient.dart';
import 'package:resonance/shared/widgets/playback_position.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';
import 'package:resonance/shared/widgets/seek_timeline.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

class PlayerBar extends ConsumerWidget {
  const PlayerBar({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackFrameProvider);
    final track = state.currentTrack ?? demoTrack;
    final library = ref.watch(libraryControllerProvider).valueOrNull;
    final favorite = library?.favoriteIds.contains(track.id) ?? false;

    // 5.0: акцент из палитры обложки (тот же источник, что у AmbientBackdrop),
    // поднятый до читаемого контраста и плавно перетекающий между треками.
    final accent = ResonanceContrast.ensure(
      watchTrackPalette(ref, track).accent,
      ResonanceColors.background,
    );
    final bar = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: accent),
      duration: ResonanceMotion.durationOf(context, ResonanceMotion.gentle),
      curve: ResonanceMotion.curve,
      builder: (context, animated, _) {
        final accent = animated ?? ResonanceColors.primary;
        return Material(
          color: compact
              ? ResonanceColors.surfaceRaised
              : const Color(0xFF09070C),
          child: Container(
            height: compact ? 70 : 88,
            decoration: BoxDecoration(
              border: compact
                  ? null
                  : const Border(
                      top: BorderSide(color: ResonanceColors.border),
                    ),
              // 5.0: мягкий отсвет обложки слева направо.
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: .14),
                  accent.withValues(alpha: 0),
                ],
                stops: const [0, .55],
              ),
            ),
            child: Column(
              children: [
                SmoothPlaybackPosition(
                  builder: (context, position, duration) {
                    final durationMs = duration.inMilliseconds;
                    return SeekTimeline(
                      value: durationMs <= 0
                          ? 0
                          : position.inMilliseconds / durationMs,
                      height: 18,
                      color: accent,
                      onSeek: (value) => unawaited(
                        ref
                            .read(playbackServiceProvider.future)
                            .then(
                              (service) => service.seek(
                                Duration(
                                  milliseconds: (durationMs * value).round(),
                                ),
                              ),
                            ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/player'),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 12 : 20,
                      ),
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: ResonanceRadii.artwork,
                              boxShadow: ResonanceShadows.low,
                            ),
                            child: ResonanceTrackSwap(
                              child: TrackArtwork(
                                key: ValueKey(track.id),
                                track: track,
                                size: compact ? 46 : 56,
                                borderRadius: ResonanceRadii.sm,
                                fallbackAsset:
                                    'assets/images/resonance_fallback_cover.png',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (compact)
                            Expanded(child: _TrackInfo(track: track))
                          else
                            SizedBox(
                              width: 250,
                              child: _TrackInfo(track: track),
                            ),
                          if (!compact) ...[
                            IconButton(
                              tooltip: favorite
                                  ? 'Убрать из избранного'
                                  : 'Добавить в избранное',
                              onPressed: () => unawaited(
                                ref
                                    .read(libraryControllerProvider.notifier)
                                    .toggleFavorite(track),
                              ),
                              icon: Icon(
                                favorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: favorite
                                    ? Theme.of(context).colorScheme.primary
                                    : ResonanceColors.text,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (!compact)
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: 'Предыдущий',
                                    onPressed: () => unawaited(
                                      ref
                                          .read(playbackServiceProvider.future)
                                          .then(
                                            (service) => service.previous(),
                                          ),
                                    ),
                                    icon: const Icon(
                                      Icons.skip_previous_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _PlayButton(state: state),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Следующий',
                                    onPressed: () => unawaited(
                                      ref
                                          .read(playbackServiceProvider.future)
                                          .then((service) => service.next()),
                                    ),
                                    icon: const Icon(Icons.skip_next_rounded),
                                  ),
                                ],
                              ),
                            )
                          else
                            _PlayButton(state: state),
                          if (!compact) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 174,
                              child: Row(
                                children: [
                                  const Icon(Icons.volume_up_rounded, size: 19),
                                  Expanded(
                                    child: Slider(
                                      value: state.volume.clamp(0, 100),
                                      max: 100,
                                      onChanged: (value) => unawaited(
                                        ref
                                            .read(
                                              playbackServiceProvider.future,
                                            )
                                            .then(
                                              (service) =>
                                                  service.setVolume(value),
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!compact) return bar;
    // На телефоне мини-плеер — отдельная плавающая карточка над панелью вкладок.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(22), child: bar),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.track});

  final UnifiedTrack track;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => openArtist(context, track.artist),
            child: Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ResonanceColors.muted,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.state});

  final ResonancePlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton.filled(
      tooltip: state.playing ? 'Пауза' : 'Воспроизвести',
      onPressed: () => unawaited(
        ref.read(playbackServiceProvider.future).then((service) {
          if (state.currentTrack == null) {
            return service.playTrack(demoTrack);
          }
          return state.playing ? service.pause() : service.play();
        }),
      ),
      icon: state.buffering
          ? const SizedBox.square(
              dimension: 19,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : AnimatedSwitcher(
              duration: ResonanceMotion.quick,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(state.playing),
              ),
            ),
    );
  }
}
