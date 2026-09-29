import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/player/track_action.dart';
import 'package:resonance/features/rooms/room_controller.dart';
import 'package:resonance/features/wave/wave_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/ambient.dart';
import 'package:resonance/shared/widgets/playback_position.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(waveControllerProvider.notifier).resume());
      unawaited(ref.read(waveControllerProvider.notifier).loadProfile());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackFrameProvider);
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
              colors: [Color(0xF5070609), Color(0xA8070609), Color(0x38070609)],
              stops: [0, .55, 1],
            ),
          ),
        ),
        Opacity(
          opacity: .7,
          child: AmbientBackdrop(
            track: track,
            intensity: .8,
            base: Colors.transparent,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(34, 28, 34, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ResonanceEntrance(child: _WaveCommandCenter()),
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
              ResonanceAnimatedSwap(
                alignment: AlignmentDirectional.topStart,
                child: Column(
                  key: ValueKey('track-copy-${track.id}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 610),
                      child: Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ResonanceColors.text,
                          fontFamily: ResonanceFonts.display,
                          fontSize: 46,
                          height: 1.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFB0A7BA),
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PlaybackSignal(state: state),
                    if (_waveReason(track) case final reason?) ...[
                      const SizedBox(height: 10),
                      _ReasonPill(reason: reason),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _HeroActions(state: state),
              const SizedBox(height: 22),
              _NextTrackPill(track: nextTrack),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroProgress extends ConsumerWidget {
  const _HeroProgress({required this.state});

  final ResonancePlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = state.currentTrack ?? demoTrack;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: AmbientProgress(
        duration: state.duration > Duration.zero
            ? state.duration
            : track.duration ?? Duration.zero,
        accent: watchTrackPalette(ref, track).accent,
        onSeek: (value) => fireAndForget(
          () => ref
              .read(playbackServiceProvider.future)
              .then((service) => service.seek(value)),
        ),
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
    final wave = ref.watch(waveControllerProvider);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RoundControl(
            size: 46,
            tooltip: wave.active ? 'Не нравится' : 'Перемешать',
            active: !wave.active && state.shuffle,
            icon: wave.active
                ? Icons.thumb_down_alt_outlined
                : Icons.shuffle_rounded,
            onPressed: wave.active
                ? () => unawaited(
                    ref
                        .read(waveControllerProvider.notifier)
                        .rateCurrent(liked: false),
                  )
                : () => unawaited(
                    service.then((value) => value.setShuffle(!state.shuffle)),
                  ),
          ),
          RoundControl(
            size: 46,
            tooltip: 'Предыдущий трек',
            icon: Icons.skip_previous_rounded,
            onPressed: () =>
                unawaited(service.then((value) => value.previous())),
          ),
          CreamPlayButton(
            size: 64,
            playing: state.playing,
            buffering: state.buffering,
            onPressed: () => unawaited(
              service.then((value) {
                if (state.currentTrack == null) {
                  return value.playTrack(demoTrack);
                }
                return state.playing ? value.pause() : value.play();
              }),
            ),
          ),
          RoundControl(
            size: 46,
            tooltip: 'Следующий трек',
            icon: Icons.skip_next_rounded,
            onPressed: () => unawaited(service.then((value) => value.next())),
          ),
          RoundControl(
            size: 46,
            tooltip: wave.active ? 'Нравится' : 'Повтор',
            active: !wave.active && state.repeatMode != PlaybackRepeatMode.off,
            icon: wave.active
                ? Icons.thumb_up_alt_outlined
                : Icons.repeat_rounded,
            onPressed: wave.active
                ? () => unawaited(
                    ref
                        .read(waveControllerProvider.notifier)
                        .rateCurrent(liked: true),
                  )
                : () => unawaited(
                    service.then(
                      (value) => value.setRepeatMode(
                        state.repeatMode == PlaybackRepeatMode.off
                            ? PlaybackRepeatMode.all
                            : PlaybackRepeatMode.off,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Действия hero на десктопе: основная кнопка, вход в Stage и оценка Wave.
/// Перемотка и переключение треков — в нижнем плеере.
class _HeroActions extends ConsumerWidget {
  const _HeroActions({required this.state});

  final ResonancePlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wave = ref.watch(waveControllerProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CreamPlayButton(
          size: 60,
          playing: state.playing,
          buffering: state.buffering,
          onPressed: () => fireAndForget(
            () => ref.read(playbackServiceProvider.future).then((service) {
              if (state.currentTrack == null) {
                return service.playTrack(demoTrack);
              }
              return state.playing ? service.pause() : service.play();
            }),
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: () => context.push('/stage'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEAE2F1),
            backgroundColor: const Color(0x14FFFFFF),
            side: const BorderSide(color: Color(0x2EFFFFFF)),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          icon: const Icon(Icons.lyrics_rounded, size: 18),
          label: const Text('Visual Stage'),
        ),
        if (wave.active) ...[
          const SizedBox(width: 12),
          RoundControl(
            tooltip: 'Не нравится',
            icon: Icons.thumb_down_alt_outlined,
            size: 48,
            onPressed: () => unawaited(
              ref
                  .read(waveControllerProvider.notifier)
                  .rateCurrent(liked: false),
            ),
          ),
          const SizedBox(width: 10),
          RoundControl(
            tooltip: 'Нравится',
            icon: Icons.thumb_up_alt_outlined,
            size: 48,
            onPressed: () => unawaited(
              ref
                  .read(waveControllerProvider.notifier)
                  .rateCurrent(liked: true),
            ),
          ),
        ],
      ],
    );
  }
}

class _PlaybackSignal extends StatelessWidget {
  const _PlaybackSignal({required this.state, this.compact = false});

  final ResonancePlaybackState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final track = state.currentTrack;
    final provider =
        state.activeTrackSource?.provider ??
        track?.preferredProvider ??
        (track?.sources.isNotEmpty == true
            ? track!.sources.first.provider
            : null);
    final audio = state.activeAudioSource;
    final bitrate = audio?.bitrate;
    final technical = bitrate != null && bitrate > 0
        ? '${(bitrate / 1000).round()} kbps'
        : audio?.codec?.replaceAll('_', ' ').toUpperCase();
    final status = state.buffering
        ? 'БУФЕРИЗАЦИЯ'
        : state.playing
        ? 'В ЭФИРЕ'
        : 'ПАУЗА';

    return Semantics(
      label: state.playing
          ? 'Трек воспроизводится'
          : 'Воспроизведение приостановлено',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 11 : 10,
          vertical: compact ? 8 : 7,
        ),
        decoration: BoxDecoration(
          color: compact ? const Color(0xC20A070D) : const Color(0x990A070D),
          borderRadius: BorderRadius.circular(compact ? 12 : 999),
          border: Border.all(color: const Color(0x40FFFFFF)),
        ),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: ResonanceMotion.quick,
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: state.playing
                    ? ResonanceColors.live
                    : ResonanceColors.muted,
                shape: BoxShape.circle,
                boxShadow: state.playing
                    ? const [BoxShadow(color: Color(0x88D8F15A), blurRadius: 8)]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: const TextStyle(
                fontFamily: ResonanceFonts.mono,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.05,
              ),
            ),
            if (provider != null) ...[
              const SizedBox(width: 9),
              Container(width: 1, height: 14, color: const Color(0x36FFFFFF)),
              const SizedBox(width: 9),
              ProviderBadge(provider: provider, compact: true),
            ],
            if (technical != null && technical.isNotEmpty) ...[
              const SizedBox(width: 9),
              Text(
                technical,
                style: const TextStyle(
                  color: ResonanceColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
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
        color: const Color(0xB20D0A10),
        border: Border.all(color: ResonanceColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        track == null
            ? 'Далее: выберите следующий трек в поиске'
            : 'Далее: ${track!.title} — ${track!.artist}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFFC0AAD6), fontSize: 12),
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
        color: Color(0xFF08060B),
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
              separatorBuilder: (_, _) => const SizedBox(height: 14),
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
    return ResonancePressable(
      hoverScale: 1.01,
      hoverOffset: Offset.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => unawaited(playTrackOrOpenOfficial(ref, track)),
        child: Row(
          children: [
            TrackArtwork(
              track: track,
              size: 48,
              borderRadius: 10,
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: ResonanceColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Transform.scale(
                        scale: .8,
                        child: ProviderBadge(provider: provider, compact: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
      children: [
        const ResonanceEntrance(child: _WaveCommandCenter()),
        const SizedBox(height: 22),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x1FFFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x52000000),
                blurRadius: 30,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: AspectRatio(
              aspectRatio: 1.08,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  track.artworkUrl == null
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
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xB3000000)],
                        stops: [.55, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: _PlaybackSignal(state: state, compact: true),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        ResonanceAnimatedSwap(
          alignment: AlignmentDirectional.topStart,
          child: Column(
            key: ValueKey('compact-track-${track.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: ResonanceFonts.display,
                  fontSize: 38,
                  height: .95,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                track.artist,
                style: const TextStyle(
                  color: ResonanceColors.muted,
                  fontSize: 17,
                ),
              ),
              if (_waveReason(track) case final reason?) ...[
                const SizedBox(height: 10),
                _ReasonPill(reason: reason),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        _HeroProgress(state: state),
        const SizedBox(height: 18),
        _HeroControls(state: state),
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

class _WaveCommandCenter extends ConsumerStatefulWidget {
  const _WaveCommandCenter();

  @override
  ConsumerState<_WaveCommandCenter> createState() => _WaveCommandCenterState();
}

class _WaveCommandCenterState extends ConsumerState<_WaveCommandCenter> {
  final TextEditingController _controller = TextEditingController();

  static const _scenes = [
    _WaveScene(
      'Ваш день',
      'Знакомое + немного нового',
      Icons.center_focus_strong_rounded,
      'Мой персональный микс на сегодня: любимое и немного новых открытий',
      Color(0xFFB499FF),
    ),
    _WaveScene(
      'Дорога',
      'Ритм без остановок',
      Icons.route_rounded,
      'Энергичная музыка в дорогу, постепенно добавляй новое',
      Color(0xFF7B68EE),
    ),
    _WaveScene(
      'После полуночи',
      'Тише, глубже, темнее',
      Icons.nightlight_round,
      'Тёплая спокойная музыка для позднего вечера',
      Color(0xFF3A78FF),
    ),
    _WaveScene(
      'Открытия',
      'За пределами привычного',
      Icons.explore_rounded,
      'Удиви меня новой музыкой рядом с моим вкусом',
      Color(0xFF3ECF8E),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start([String? scene]) async {
    final prompt = (scene ?? _controller.text).trim();
    if (scene != null) {
      _controller.value = TextEditingValue(
        text: scene,
        selection: TextSelection.collapsed(offset: scene.length),
      );
    }
    final favorites = ref
        .read(libraryControllerProvider)
        .valueOrNull
        ?.favorites;
    final hasBackend = BackendEndpoint.displayValue.isNotEmpty;
    final room = hasBackend ? ref.read(roomControllerProvider) : null;
    final roomController = hasBackend
        ? ref.read(roomControllerProvider.notifier)
        : null;
    await ref
        .read(waveControllerProvider.notifier)
        .start(
          taste: favorites ?? const [],
          prompt: prompt,
          roomCode: room?.inRoom == true && roomController?.isHost == true
              ? room?.code
              : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final wave = ref.watch(waveControllerProvider);
    final profile = wave.profile;
    final hasBackend = BackendEndpoint.displayValue.isNotEmpty;
    final room = hasBackend ? ref.watch(roomControllerProvider) : null;
    final shared =
        room?.inRoom == true &&
        ref.read(roomControllerProvider.notifier).isHost;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xD90B090E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ResonanceColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: ResonanceMotion.standard,
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: wave.active
                          ? ResonanceColors.success
                          : Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: wave.active
                          ? const [
                              BoxShadow(
                                color: Color(0x665DDAA3),
                                blurRadius: 9,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    shared ? 'ОБЩАЯ RESONANCE WAVE 2.0' : 'RESONANCE WAVE 2.0',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Открыть поиск',
                    onPressed: () => context.go('/search'),
                    icon: const Icon(Icons.search_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                enabled: !wave.loading,
                maxLength: 500,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => unawaited(_start()),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Какую музыку включить?',
                  prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 20),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(5),
                    child: IconButton.filled(
                      tooltip: wave.active
                          ? 'Перестроить волну'
                          : 'Запустить волну',
                      onPressed: wave.loading
                          ? null
                          : () => unawaited(_start()),
                      icon: wave.loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_upward_rounded, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _scenes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 9),
                  itemBuilder: (context, index) {
                    final scene = _scenes[index];
                    return _WaveMixCard(
                      scene: scene,
                      enabled: !wave.loading,
                      onTap: () => unawaited(_start(scene.prompt)),
                    );
                  },
                ),
              ),
              if (profile != null && profile.weekTracks > 0) ...[
                const SizedBox(height: 10),
                _WaveWeekStrip(profile: profile),
              ],
              AnimatedSize(
                duration: ResonanceMotion.standard,
                curve: ResonanceMotion.curve,
                child: wave.active || wave.error != null || profile != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                wave.error ??
                                    wave.summary ??
                                    (profile == null
                                        ? 'Волна учитывает дослушивания и пропуски'
                                        : 'Музыкальная память: ${profile.signalCount} сигналов${profile.topArtists.isEmpty ? '' : ' · ${profile.topArtists.take(2).join(', ')}'}'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: wave.error == null
                                      ? ResonanceColors.muted
                                      : Theme.of(context).colorScheme.error,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            if (wave.active) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () => unawaited(
                                  ref
                                      .read(waveControllerProvider.notifier)
                                      .stop(),
                                ),
                                icon: const Icon(Icons.stop_rounded, size: 17),
                                label: const Text('Стоп'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveScene {
  const _WaveScene(
    this.label,
    this.subtitle,
    this.icon,
    this.prompt,
    this.color,
  );
  final String label;
  final String subtitle;
  final IconData icon;
  final String prompt;
  final Color color;
}

class _WaveMixCard extends StatelessWidget {
  const _WaveMixCard({
    required this.scene,
    required this.enabled,
    required this.onTap,
  });

  final _WaveScene scene;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ResonancePressable(
    enabled: enabled,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 190,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scene.color.withValues(alpha: .42)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scene.color.withValues(alpha: .22),
                const Color(0xFF110D15),
              ],
            ),
          ),
          child: Row(
            children: [
              Icon(scene.icon, color: scene.color, size: 22),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      scene.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ResonanceColors.muted,
                        fontSize: 9,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WaveWeekStrip extends StatelessWidget {
  const _WaveWeekStrip({required this.profile});
  final WaveProfile profile;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: ResonanceColors.surfaceHigh,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: ResonanceColors.border),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.insights_rounded,
          size: 18,
          color: ResonanceColors.primary,
        ),
        const SizedBox(width: 9),
        const Text(
          'НЕДЕЛЯ',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              children: [
                Text(
                  '${profile.weekTracks} треков',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${profile.weekMinutes} мин',
                  style: const TextStyle(
                    color: ResonanceColors.muted,
                    fontSize: 10,
                  ),
                ),
                if (profile.weekDiscoveries > 0) ...[
                  const SizedBox(width: 12),
                  Text(
                    '+${profile.weekDiscoveries} любимых',
                    style: const TextStyle(
                      color: ResonanceColors.success,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReasonPill extends StatelessWidget {
  const _ReasonPill({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              reason,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
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
    final image = artwork == null
        ? Image.asset(
            'assets/images/resonance_fallback_cover.png',
            key: ValueKey('fallback-${track.id}'),
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          )
        : CachedNetworkImage(
            key: ValueKey('artwork-${track.id}'),
            imageUrl: highQualityArtworkUrl(artwork),
            memCacheWidth: 1400,
            maxWidthDiskCache: 1400,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            fadeInDuration: ResonanceMotion.standard,
            fadeOutDuration: ResonanceMotion.quick,
            errorWidget: (_, _, _) => Image.asset(
              'assets/images/resonance_fallback_cover.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
          );
    return ResonanceCrossfade(
      child: SizedBox.expand(key: ValueKey(track.id), child: image),
    );
  }
}

String? _waveReason(UnifiedTrack track) {
  for (final source in track.sources) {
    final reason = source.metadata['waveReason'];
    if (reason is String && reason.trim().isNotEmpty) return reason.trim();
  }
  return null;
}
