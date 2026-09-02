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
import 'package:resonance/shared/widgets/provider_badges.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';
import 'package:resonance/shared/widgets/seek_timeline.dart';
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
                    if (_waveReason(track) case final reason?) ...[
                      const SizedBox(height: 10),
                      _ReasonPill(reason: reason),
                    ],
                  ],
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
    final wave = ref.watch(waveControllerProvider);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: wave.active ? 'Не нравится' : 'Перемешать',
            onPressed: wave.active
                ? () => unawaited(
                    ref
                        .read(waveControllerProvider.notifier)
                        .rateCurrent(liked: false),
                  )
                : () => unawaited(
                    service.then((value) => value.setShuffle(!state.shuffle)),
                  ),
            icon: Icon(
              wave.active
                  ? Icons.thumb_down_alt_outlined
                  : Icons.shuffle_rounded,
            ),
          ),
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
          IconButton(
            tooltip: wave.active ? 'Нравится' : 'Повтор',
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
            icon: Icon(
              wave.active ? Icons.thumb_up_alt_outlined : Icons.repeat_rounded,
            ),
          ),
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
        const ResonanceEntrance(child: _WaveCommandCenter()),
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
        ResonanceAnimatedSwap(
          child: Column(
            key: ValueKey('compact-track-${track.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
      'Работа',
      Icons.center_focus_strong_rounded,
      'Спокойная музыка для глубокой работы, сначала знакомое',
    ),
    _WaveScene(
      'Дорога',
      Icons.route_rounded,
      'Энергичная музыка в дорогу, постепенно добавляй новое',
    ),
    _WaveScene(
      'Вечер',
      Icons.nightlight_round,
      'Тёплая спокойная музыка для позднего вечера',
    ),
    _WaveScene(
      'Открытия',
      Icons.explore_rounded,
      'Удиви меня новой музыкой рядом с моим вкусом',
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
          color: const Color(0xD90B0B0C),
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
                    shared ? 'ОБЩАЯ RESONANCE WAVE' : 'RESONANCE WAVE',
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
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final scene in _scenes) ...[
                      ActionChip(
                        avatar: Icon(scene.icon, size: 17),
                        label: Text(scene.label),
                        onPressed: wave.loading
                            ? null
                            : () => unawaited(_start(scene.prompt)),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
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
  const _WaveScene(this.label, this.icon, this.prompt);
  final String label;
  final IconData icon;
  final String prompt;
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
    return ResonanceAnimatedSwap(
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

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
