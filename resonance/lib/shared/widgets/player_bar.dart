import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

class PlayerBar extends ConsumerWidget {
  const PlayerBar({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackStateProvider);
    final state = playback.valueOrNull ?? const ResonancePlaybackState();
    final track = state.currentTrack ?? demoTrack;
    final library = ref.watch(libraryControllerProvider).valueOrNull;
    final favorite = library?.favoriteIds.contains(track.id) ?? false;
    final durationMs = state.duration.inMilliseconds;
    final progress = durationMs <= 0
        ? 0.0
        : (state.position.inMilliseconds / durationMs).clamp(0.0, 1.0);

    return Material(
      color: const Color(0xFF0A0A09),
      child: Container(
        height: compact ? 74 : 88,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: ResonanceColors.border)),
        ),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: ResonanceColors.border,
              color: ResonanceColors.primary,
            ),
            Expanded(
              child: InkWell(
                onTap: () => context.push('/player'),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20),
                  child: Row(
                    children: [
                      TrackArtwork(
                        track: track,
                        size: compact ? 44 : 54,
                        borderRadius: 10,
                        fallbackAsset:
                            'assets/images/resonance_fallback_cover.png',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ResonanceColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
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
                                ? ResonanceColors.primary
                                : ResonanceColors.text,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => unawaited(
                            ref
                                .read(playbackServiceProvider.future)
                                .then((service) => service.previous()),
                          ),
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                      ],
                      _PlayButton(state: state),
                      if (!compact) ...[
                        IconButton(
                          onPressed: () => unawaited(
                            ref
                                .read(playbackServiceProvider.future)
                                .then((service) => service.next()),
                          ),
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                        const Spacer(),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 130,
                          child: Slider(
                            value: state.volume.clamp(0, 100),
                            max: 100,
                            onChanged: (value) => unawaited(
                              ref
                                  .read(playbackServiceProvider.future)
                                  .then((service) => service.setVolume(value)),
                            ),
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
          : Icon(
              state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
    );
  }
}
