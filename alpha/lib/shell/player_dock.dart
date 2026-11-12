import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/screens/now_playing_screen.dart';
import 'package:resonance_alpha/screens/queue_sheet.dart';
import 'package:resonance_alpha/state.dart';

/// The player that follows you around. On a phone it is a floating capsule
/// tinted with the cover; on desktop a full-width dock with volume.
class PlayerDock extends ConsumerWidget {
  const PlayerDock({required this.wide, super.key});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    if (track == null) return const SizedBox.shrink();
    final accent = ref.watch(currentAccentProvider);
    final playing = ref.watch(
      playbackStateProvider.select((s) => s.valueOrNull?.playing ?? false),
    );
    final liked = ref.watch(favoriteIdsProvider).contains(track.id);
    // Failures get their own card (PlaybackIssueBar); the dock only carries
    // short notices such as a source switch.
    final error = ref.watch(
      playbackStateProvider.select((s) => s.valueOrNull?.sourceShiftMessage),
    );
    void open() => Navigator.of(context).push(NowPlayingScreen.route());
    Future<void> next() async {
      final service = await ref.read(playbackServiceProvider.future);
      await service.next();
    }

    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Txt.body(wide ? 15 : 14.5, weight: 750),
        ),
        Text(
          error ?? track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Txt.body(12.5, color: error == null ? Pal.muted : accent),
        ),
      ],
    );

    if (!wide) {
      return Press(
        onTap: open,
        scale: .98,
        child: AnimatedContainer(
          duration: Motion.slow,
          height: 64,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: Color.lerp(accent, Pal.stage, .72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: .35)),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'cover',
                    child: TrackArtwork(
                      track: track,
                      size: 48,
                      borderRadius: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: titles),
                  Press(
                    onTap: () => run(context, () => toggleFavorite(ref, track)),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: liked ? accent : Pal.paper,
                      ),
                    ),
                  ),
                  Knob(
                    icon: playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 44,
                    filled: true,
                    color: Pal.paper,
                    onTap: () => run(context, () => togglePlay(ref)),
                  ),
                ],
              ),
              Positioned(
                left: 60,
                right: 60,
                bottom: -6,
                child: _Progress(accent: accent, height: 2),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 84,
      decoration: const BoxDecoration(
        color: Pal.stage,
        border: Border(top: BorderSide(color: Pal.line)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _Progress(accent: accent, height: 3),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Press(
                    onTap: open,
                    scale: .99,
                    child: Row(
                      children: [
                        Hero(
                          tag: 'cover',
                          child: TrackArtwork(
                            track: track,
                            size: 52,
                            borderRadius: 12,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Flexible(child: titles),
                        const SizedBox(width: 10),
                        Press(
                          onTap: () =>
                              run(context, () => toggleFavorite(ref, track)),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 20,
                              color: liked ? accent : Pal.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Knob(
                  icon: Icons.skip_previous_rounded,
                  size: 42,
                  onTap: () => run(context, () async {
                    final service = await ref.read(
                      playbackServiceProvider.future,
                    );
                    await service.previous();
                  }),
                ),
                const SizedBox(width: 12),
                Knob(
                  icon: playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 54,
                  filled: true,
                  color: accent,
                  iconColor: onAccent(accent),
                  onTap: () => run(context, () => togglePlay(ref)),
                ),
                const SizedBox(width: 12),
                Knob(
                  icon: Icons.skip_next_rounded,
                  size: 42,
                  onTap: () => run(context, next),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Press(
                        tooltip: 'Очередь',
                        onTap: () => showQueueSheet(context),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.queue_music_rounded,
                            color: Pal.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _Volume(accent: accent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Progress extends ConsumerWidget {
  const _Progress({required this.accent, required this.height});

  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fraction = ref.watch(
      playbackStateProvider.select((value) {
        final state = value.valueOrNull;
        final total = state?.duration.inMilliseconds ?? 0;
        if (state == null || total <= 0) return 0.0;
        // Rounded so the bar repaints about 500 times per track, not per tick.
        return (state.position.inMilliseconds / total * 500).round() / 500;
      }),
    );
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          heightFactor: 1,
          child: ColoredBox(color: accent),
        ),
      ),
    );
  }
}

class _Volume extends ConsumerWidget {
  const _Volume({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(
      playbackStateProvider.select((s) => s.valueOrNull?.volume ?? 70),
    );
    return SizedBox(
      width: 140,
      child: Row(
        children: [
          Icon(
            volume <= 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            size: 18,
            color: Pal.muted,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Pal.paper,
                inactiveTrackColor: Pal.line,
                thumbColor: Pal.paper,
                overlayColor: accent.withValues(alpha: .2),
              ),
              child: Slider(
                value: volume.clamp(0, 100).toDouble(),
                max: 100,
                onChanged: (value) => run(context, () async {
                  final service = await ref.read(
                    playbackServiceProvider.future,
                  );
                  await service.setVolume(value);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
