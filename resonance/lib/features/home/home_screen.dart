import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/player/track_action.dart';
import 'package:resonance/features/wave/wave_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';
import 'package:resonance/shared/widgets/seek_timeline.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackStateProvider);
    final state = playback.valueOrNull ?? const ResonancePlaybackState();
    final track = state.currentTrack ?? demoTrack;
    final library = ref.watch(libraryControllerProvider).valueOrNull;
    final recent = <UnifiedTrack>[
      ...state.queue,
      ...?library?.favorites.where((item) => item.id != track.id),
    ];
    final uniqueRecent = <String, UnifiedTrack>{
      for (final item in recent) item.id: item,
    }.values.take(6).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 880;
        if (compact) {
          return _CompactHome(
            track: track,
            state: state,
            nextTrack: _nextTrack(state),
            recent: uniqueRecent,
          );
        }
        return Row(
          children: [
            Expanded(
              child: _CinematicPlayer(
                track: track,
                state: state,
                nextTrack: _nextTrack(state),
              ),
            ),
            SizedBox(
              width: constraints.maxWidth >= 1180 ? 282 : 238,
              child: _RecentRail(tracks: uniqueRecent),
            ),
          ],
        );
      },
    );
  }

  UnifiedTrack? _nextTrack(ResonancePlaybackState state) {
    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= 0 && nextIndex < state.queue.length) {
      return state.queue[nextIndex];
    }
    return null;
  }
}

class _CinematicPlayer extends StatelessWidget {
  const _CinematicPlayer({
    required this.track,
    required this.state,
    required this.nextTrack,
  });

  final UnifiedTrack track;
  final ResonancePlaybackState state;
  final UnifiedTrack? nextTrack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _TrackBackdrop(track: track),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xF5080909), Color(0xA8080909), Color(0x38080909)],
              stops: [0, .55, 1],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(34, 28, 34, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchLauncher(onTap: () => context.go('/search')),
              const SizedBox(height: 12),
              const _WaveButton(),
              const Spacer(flex: 2),
              const Row(
                children: [
                  SizedBox.square(
                    dimension: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ResonanceColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'СЕЙЧАС ИГРАЕТ',
                    style: TextStyle(
                      color: ResonanceColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 610),
                child: Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ResonanceColors.text,
                    fontSize: 60,
                    height: .92,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -3.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB7B0AA),
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 36),
              _HeroProgress(state: state),
              const SizedBox(height: 24),
              _HeroControls(state: state),
              const SizedBox(height: 24),
              _NextTrackPill(track: nextTrack),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: Material(
        color: const Color(0xB20D0D0D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: ResonanceColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: const SizedBox(
            height: 50,
            child: Row(
              children: [
                SizedBox(width: 16),
                Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: ResonanceColors.muted,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Трек, артист, альбом, плейлист',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ResonanceColors.muted,
                      fontSize: 14,
                    ),
                  ),
                ),
                SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroProgress extends ConsumerWidget {
  const _HeroProgress({required this.state});

  final ResonancePlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = state.duration.inMilliseconds;
    final value = total <= 0
        ? 0.18
        : (state.position.inMilliseconds / total).clamp(0.0, 1.0);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        children: [
          SeekTimeline(
            value: value,
            height: 22,
            onSeek: (fraction) => unawaited(
              ref
                  .read(playbackServiceProvider.future)
                  .then(
                    (service) => service.seek(
                      Duration(milliseconds: (total * fraction).round()),
                    ),
                  ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Text(_formatDuration(state.position)),
              const Spacer(),
              Text(_formatDuration(state.duration)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroControls extends ConsumerWidget {
  const _HeroControls({required this.state});

  final ResonancePlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(playbackServiceProvider.future);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.shuffle_rounded)),
          IconButton(
            onPressed: () =>
                unawaited(service.then((value) => value.previous())),
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          SizedBox.square(
            dimension: 66,
            child: IconButton.filled(
              onPressed: () => unawaited(
                service.then((value) {
                  if (state.currentTrack == null) {
                    return value.playTrack(demoTrack);
                  }
                  return state.playing ? value.pause() : value.play();
                }),
              ),
              iconSize: 30,
              icon: state.buffering
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Icon(
                      state.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
            ),
          ),
          IconButton(
            onPressed: () => unawaited(service.then((value) => value.next())),
            icon: const Icon(Icons.skip_next_rounded),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.repeat_rounded)),
        ],
      ),
    );
  }
}

class _NextTrackPill extends StatelessWidget {
  const _NextTrackPill({required this.track});

  final UnifiedTrack? track;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xB20D0D0D),
        border: Border.all(color: ResonanceColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        track == null
            ? 'Далее: выберите следующий трек в поиске'
            : 'Далее: ${track!.title} — ${track!.artist}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFFC8C1B8), fontSize: 12),
      ),
    );
  }
}

class _RecentRail extends StatelessWidget {
  const _RecentRail({required this.tracks});

  final List<UnifiedTrack> tracks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 34, 18, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF080909),
        border: Border(left: BorderSide(color: ResonanceColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'НЕДАВНО',
            style: TextStyle(
              color: ResonanceColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          if (tracks.isEmpty)
            const Expanded(child: _EmptyRecent())
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tracks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) =>
                  _RecentTrack(track: tracks[index]),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: () => context.go('/library'),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Открыть медиатеку'),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 28),
      child: Text(
        'Здесь появятся последние треки и избранное.',
        style: TextStyle(
          color: ResonanceColors.muted,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}

class _RecentTrack extends ConsumerWidget {
  const _RecentTrack({required this.track});

  final UnifiedTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider =
        track.preferredProvider ??
        (track.sources.isEmpty
            ? MusicProvider.soundcloud
            : track.sources.first.provider);
    return InkWell(
      onTap: () => unawaited(playTrackOrOpenOfficial(ref, track)),
      child: Row(
        children: [
          TrackArtwork(
            track: track,
            size: 52,
            borderRadius: 4,
            fallbackAsset: 'assets/images/resonance_fallback_cover.png',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ResonanceColors.muted,
                  ),
                ),
                const SizedBox(height: 5),
                ProviderBadge(provider: provider, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactHome extends StatelessWidget {
  const _CompactHome({
    required this.track,
    required this.state,
    required this.nextTrack,
    required this.recent,
  });

  final UnifiedTrack track;
  final ResonancePlaybackState state;
  final UnifiedTrack? nextTrack;
  final List<UnifiedTrack> recent;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
      children: [
        _SearchLauncher(onTap: () => context.go('/search')),
        const SizedBox(height: 12),
        const _WaveButton(),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 1.08,
            child: track.artworkUrl == null
                ? Image.asset(
                    'assets/images/resonance_fallback_cover.png',
                    fit: BoxFit.cover,
                  )
                : CachedNetworkImage(
                    imageUrl: highQualityArtworkUrl(track.artworkUrl!),
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Image.asset(
                      'assets/images/resonance_fallback_cover.png',
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          track.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 38,
            height: .95,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          track.artist,
          style: const TextStyle(color: ResonanceColors.muted, fontSize: 17),
        ),
        const SizedBox(height: 22),
        _HeroProgress(state: state),
        const SizedBox(height: 16),
        _NextTrackPill(track: nextTrack),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 32),
          const Text(
            'НЕДАВНО',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          for (final item in recent) ...[
            _RecentTrack(track: item),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }
}

class _WaveButton extends ConsumerWidget {
  const _WaveButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wave = ref.watch(waveControllerProvider);
    final favorites = ref
        .watch(libraryControllerProvider)
        .valueOrNull
        ?.favorites;
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: wave.loading
            ? null
            : () => wave.active
                  ? unawaited(ref.read(waveControllerProvider.notifier).stop())
                  : unawaited(
                      ref
                          .read(waveControllerProvider.notifier)
                          .start(taste: favorites ?? const []),
                    ),
        icon: wave.loading
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(wave.active ? Icons.stop_rounded : Icons.graphic_eq_rounded),
        label: Text(
          wave.loading
              ? 'Подбираем…'
              : wave.active
              ? 'Остановить волну'
              : 'Моя волна',
        ),
      ),
    );
  }
}

class _TrackBackdrop extends ConsumerWidget {
  const _TrackBackdrop({required this.track});
  final UnifiedTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appearanceControllerProvider).backgroundPath != null) {
      return const SizedBox.expand();
    }
    final artwork = track.artworkUrl;
    if (artwork == null) {
      return Image.asset(
        'assets/images/resonance_fallback_cover.png',
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
      );
    }
    return CachedNetworkImage(
      imageUrl: highQualityArtworkUrl(artwork),
      memCacheWidth: 1400,
      maxWidthDiskCache: 1400,
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
      errorWidget: (_, _, _) => Image.asset(
        'assets/images/resonance_fallback_cover.png',
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
