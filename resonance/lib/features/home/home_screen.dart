import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/artist/artist_catalog.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/player/track_action.dart';
import 'package:resonance/features/rooms/room_controller.dart';
import 'package:resonance/features/wave/wave_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/ambient_backdrop.dart';
import 'package:resonance/shared/widgets/media_cards.dart';
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
    final favorites = library?.favorites ?? const <UnifiedTrack>[];
    final recent = <String, UnifiedTrack>{
      for (final item in state.queue.reversed)
        if (item.id != track.id) item.id: item,
    }.values.take(16).toList(growable: false);
    final artists = _topArtists([
      track,
      ...state.queue,
      ...favorites,
      ...?library?.tracks,
    ]);
    final palette = watchArtworkPalette(ref, track.artworkUrl);
    final theme = Theme.of(context);
    final accentTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: palette.accent,
        onPrimary: palette.onAccent,
      ),
    );

    return Theme(
      data: accentTheme,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 880;
          final gutter = compact ? 18.0 : 34.0;
          final card = compact ? 140.0 : 164.0;
          final usesCustomBackground =
              ref.watch(appearanceControllerProvider).backgroundPath != null;
          return Stack(
            children: [
              if (!usesCustomBackground)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: compact ? 1040 : 720,
                  child: AmbientBackdrop(
                    palette: palette,
                    imageUrl: track.artworkUrl,
                  ),
                ),
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _WaveHero(
                      track: track,
                      state: state,
                      palette: palette,
                      compact: compact,
                      wide: constraints.maxWidth >= 1120,
                      gutter: gutter,
                      upcoming: _upcoming(state),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ShortcutRow(
                        compact: compact,
                        history: recent,
                        favorites: favorites,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 30, gutter, 0),
                    sliver: const SliverToBoxAdapter(
                      child: ShelfHeader(title: 'Для вас'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: MediaShelf(
                      itemCount: _waveScenes.length,
                      height: card + 62,
                      itemWidth: card,
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      itemBuilder: (context, index) =>
                          _SceneCard(scene: _waveScenes[index], size: card),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 0),
                    sliver: const SliverToBoxAdapter(
                      child: ResonanceEntrance(child: _WaveCommandCenter()),
                    ),
                  ),
                  if (recent.isNotEmpty)
                    ..._trackShelf(
                      'Недавно играло',
                      recent,
                      state,
                      palette,
                      gutter,
                      card,
                    ),
                  if (favorites.isNotEmpty)
                    ..._trackShelf(
                      'Любимые треки',
                      favorites,
                      state,
                      palette,
                      gutter,
                      card,
                    ),
                  if (artists.isNotEmpty) ...[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(gutter, 30, gutter, 0),
                      sliver: const SliverToBoxAdapter(
                        child: ShelfHeader(title: 'Ваши артисты'),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: MediaShelf(
                        itemCount: artists.length,
                        height: card + 52,
                        itemWidth: card,
                        padding: EdgeInsets.symmetric(horizontal: gutter),
                        itemBuilder: (context, index) {
                          final artist = artists[index];
                          return MediaCard(
                            title: artist.name,
                            subtitle:
                                '${artist.count} ${_tracksWord(artist.count)}',
                            artworkUrl: artist.artwork,
                            size: card,
                            circular: true,
                            accent: palette.accent,
                            onTap: () => openArtist(context, artist.name),
                          );
                        },
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _trackShelf(
    String title,
    List<UnifiedTrack> tracks,
    ResonancePlaybackState state,
    ArtworkPalette palette,
    double gutter,
    double size,
  ) => [
    SliverPadding(
      padding: EdgeInsets.fromLTRB(gutter, 30, gutter, 0),
      sliver: SliverToBoxAdapter(child: ShelfHeader(title: title)),
    ),
    SliverToBoxAdapter(
      child: MediaShelf(
        itemCount: math.min(tracks.length, 20),
        height: size + 62,
        itemWidth: size,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        itemBuilder: (context, index) {
          final item = tracks[index];
          final active = state.currentTrack?.id == item.id;
          return MediaCard(
            title: item.title,
            subtitle: item.artist,
            subtitleWidget: ArtistLinks(artist: item.artist),
            artworkUrl: item.artworkUrl,
            size: size,
            accent: palette.accent,
            active: active,
            playing: state.playing,
            onTap: () => unawaited(
              active
                  ? ref
                        .read(playbackServiceProvider.future)
                        .then((s) => state.playing ? s.pause() : s.play())
                  : playTrackOrOpenOfficial(ref, item),
            ),
          );
        },
      ),
    ),
  ];

  List<UnifiedTrack> _upcoming(ResonancePlaybackState state) {
    final start = state.currentIndex + 1;
    if (start <= 0 || start >= state.queue.length) return const [];
    return state.queue.skip(start).take(3).toList(growable: false);
  }
}

final class _ArtistTile {
  _ArtistTile(this.name, this.artwork);
  final String name;
  Uri? artwork;
  int count = 0;
}

List<_ArtistTile> _topArtists(Iterable<UnifiedTrack> tracks) {
  final byKey = <String, _ArtistTile>{};
  final seen = <String>{};
  for (final track in tracks) {
    if (track.id == demoTrack.id || !seen.add(track.id)) continue;
    final name = primaryArtist(track.artist);
    final key = normalizeArtistKey(name);
    if (key.isEmpty) continue;
    final tile = byKey.putIfAbsent(
      key,
      () => _ArtistTile(name, track.artworkUrl),
    );
    tile.count++;
    tile.artwork ??= track.artworkUrl;
  }
  return (byKey.values.toList()..sort((a, b) => b.count.compareTo(a.count)))
      .take(14)
      .toList(growable: false);
}

String _tracksWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return 'трек';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'трека';
  }
  return 'треков';
}

/// Starts (or rebuilds) the personal wave with an optional prompt.
Future<void> startWave(WidgetRef ref, String prompt) async {
  final favorites = ref.read(libraryControllerProvider).valueOrNull?.favorites;
  final hasBackend = BackendEndpoint.displayValue.isNotEmpty;
  final room = hasBackend ? ref.read(roomControllerProvider) : null;
  final roomController = hasBackend
      ? ref.read(roomControllerProvider.notifier)
      : null;
  await ref
      .read(waveControllerProvider.notifier)
      .start(
        taste: favorites ?? const [],
        prompt: prompt.trim(),
        roomCode: room?.inRoom == true && roomController?.isHost == true
            ? room?.code
            : null,
      );
}

class _WaveHero extends ConsumerWidget {
  const _WaveHero({
    required this.track,
    required this.state,
    required this.palette,
    required this.compact,
    required this.wide,
    required this.gutter,
    required this.upcoming,
  });

  final UnifiedTrack track;
  final ResonancePlaybackState state;
  final ArtworkPalette palette;
  final bool compact;
  final bool wide;
  final double gutter;
  final List<UnifiedTrack> upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wave = ref.watch(waveControllerProvider);
    final cover = _HeroCover(
      track: track,
      palette: palette,
      playing: state.playing,
      size: compact ? 220 : 236,
    );
    final copy = Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Моя волна',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: ResonanceColors.text,
            fontSize: compact ? 48 : 76,
            height: .92,
            fontWeight: FontWeight.w900,
            letterSpacing: compact ? -2 : -3.6,
          ),
        ),
        const SizedBox(height: 12),
        _MoodChip(wave: wave, playing: state.playing, palette: palette),
        const SizedBox(height: 22),
        ResonanceAnimatedSwap(
          child: Column(
            key: ValueKey('track-copy-${track.id}'),
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: const TextStyle(
                  color: ResonanceColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 4),
              ArtistLinks(
                artist: track.artist,
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: const TextStyle(
                  color: Color(0xFFC9C1B8),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _PlaybackSignal(state: state),
              if (_waveReason(track) case final reason?) ...[
                const SizedBox(height: 10),
                _ReasonPill(reason: reason),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _HeroProgress(state: state),
        const SizedBox(height: 10),
        _HeroControls(state: state),
      ],
    );

    final content = compact
        ? Column(
            children: [
              cover,
              const SizedBox(height: 26),
              copy,
              const SizedBox(height: 14),
              _NextTrackPill(track: upcoming.firstOrNull),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              cover,
              const SizedBox(width: 40),
              Expanded(child: copy),
              if (wide) ...[
                const SizedBox(width: 24),
                _UpNextCluster(
                  tracks: upcoming,
                  palette: palette,
                  state: state,
                ),
              ],
            ],
          );

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            compact ? 26 : 44,
            gutter,
            compact ? 24 : 40,
          ),
          child: ResonanceEntrance(child: content),
        ),
      ],
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.wave,
    required this.playing,
    required this.palette,
  });

  final WaveState wave;
  final bool playing;
  final ArtworkPalette palette;

  @override
  Widget build(BuildContext context) {
    final scene = _waveScenes
        .where((scene) => scene.prompt == wave.prompt)
        .firstOrNull;
    final label = wave.loading
        ? 'Настраиваем…'
        : wave.active
        ? scene?.label ?? (wave.prompt.isEmpty ? 'Обычная' : 'Своя')
        : 'Не запущена';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EqualizerBars(
            playing: playing && wave.active,
            color: palette.accent,
            size: 12,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: ResonanceColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The current cover, gently breathing while music plays.
class _HeroCover extends ConsumerStatefulWidget {
  const _HeroCover({
    required this.track,
    required this.palette,
    required this.playing,
    required this.size,
  });

  final UnifiedTrack track;
  final ArtworkPalette palette;
  final bool playing;
  final double size;

  @override
  ConsumerState<_HeroCover> createState() => _HeroCoverState();
}

class _HeroCoverState extends ConsumerState<_HeroCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_HeroCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animate =
        widget.playing && !reduced && ref.read(ambientMotionEnabledProvider);
    if (animate && !_breath.isAnimating) {
      unawaited(_breath.repeat(reverse: true));
    } else if (!animate && _breath.isAnimating) {
      unawaited(_breath.animateTo(0, duration: ResonanceMotion.gentle));
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_breath.value);
        return Transform.scale(
          scale: 1 + .018 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.palette.accent.withValues(alpha: .28 + .2 * t),
                  blurRadius: 50 + 20 * t,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 30,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox.square(
          dimension: size,
          child: ResonanceTrackSwap(
            child: TrackArtwork(
              key: ValueKey('hero-cover-${widget.track.id}'),
              track: widget.track,
              size: size,
              borderRadius: 0,
              fallbackAsset: 'assets/images/resonance_fallback_cover.png',
            ),
          ),
        ),
      ),
    );
  }
}

/// Right side of the hero: the next covers drifting on the wave and a big
/// accent play button.
class _UpNextCluster extends ConsumerStatefulWidget {
  const _UpNextCluster({
    required this.tracks,
    required this.palette,
    required this.state,
  });

  final List<UnifiedTrack> tracks;
  final ArtworkPalette palette;
  final ResonancePlaybackState state;

  @override
  ConsumerState<_UpNextCluster> createState() => _UpNextClusterState();
}

class _UpNextClusterState extends ConsumerState<_UpNextCluster>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduced && ref.read(ambientMotionEnabledProvider)) {
      if (!_float.isAnimating) unawaited(_float.repeat());
    } else {
      _float.stop();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final palette = widget.palette;
    const positions = [Offset(70, 0), Offset(0, 92), Offset(96, 168)];
    const sizes = [86.0, 70.0, 58.0];
    return SizedBox(
      width: 230,
      height: 300,
      child: AnimatedBuilder(
        animation: _float,
        builder: (context, _) {
          final phase = _float.value * math.pi * 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < widget.tracks.length && i < 3; i++)
                Positioned(
                  left: positions[i].dx,
                  top: positions[i].dy + math.sin(phase + i * 2.1) * 7,
                  child: Transform.rotate(
                    angle: math.sin(phase + i) * .05 + (i.isEven ? .06 : -.08),
                    child: Tooltip(
                      message:
                          'Далее: ${widget.tracks[i].title} — ${widget.tracks[i].artist}',
                      child: Opacity(
                        opacity: 1 - i * .18,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x88000000),
                                blurRadius: 18,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: TrackArtwork(
                            track: widget.tracks[i],
                            size: sizes[i],
                            borderRadius: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: _BigPlayButton(
                  state: state,
                  palette: palette,
                  phase: phase,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BigPlayButton extends ConsumerWidget {
  const _BigPlayButton({
    required this.state,
    required this.palette,
    required this.phase,
  });

  final ResonancePlaybackState state;
  final ArtworkPalette palette;
  final double phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wave = ref.watch(waveControllerProvider);
    final startsWave = !wave.active && BackendEndpoint.displayValue.isNotEmpty;
    final showPause = state.playing && !startsWave;
    final glow = state.playing ? .5 + .2 * math.sin(phase * 3) : .35;
    return ResonancePressable(
      hoverScale: 1.06,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: glow),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Material(
          color: palette.accent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: wave.loading
                ? null
                : () => unawaited(_toggle(ref, startsWave)),
            child: SizedBox.square(
              dimension: 92,
              child: wave.loading
                  ? Padding(
                      padding: const EdgeInsets.all(30),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: palette.onAccent,
                      ),
                    )
                  : Icon(
                      showPause
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 46,
                      color: palette.onAccent,
                      semanticLabel: startsWave
                          ? 'Запустить волну'
                          : showPause
                          ? 'Пауза'
                          : 'Продолжить',
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(WidgetRef ref, bool startsWave) async {
    if (startsWave) {
      await startWave(ref, '');
      return;
    }
    final service = await ref.read(playbackServiceProvider.future);
    if (state.currentTrack == null) return service.playTrack(demoTrack);
    return state.playing ? service.pause() : service.play();
  }
}

class _ShortcutRow extends ConsumerWidget {
  const _ShortcutRow({
    required this.compact,
    required this.history,
    required this.favorites,
  });

  final bool compact;
  final List<UnifiedTrack> history;
  final List<UnifiedTrack> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> play(List<UnifiedTrack> tracks) async {
      final playable = playableQueueTracks(tracks);
      if (playable.isEmpty) {
        context.go('/library');
        return;
      }
      final service = await ref.read(playbackServiceProvider.future);
      await service.setQueue(playable, autoplay: true);
    }

    final cards = [
      _ShortcutCard(
        icon: Icons.history_rounded,
        title: 'История',
        subtitle: history.isEmpty
            ? 'Здесь появятся недавно прослушанные треки'
            : 'Ваши недавно прослушанные треки',
        tracks: history,
        onTap: () => unawaited(play(history)),
      ),
      _ShortcutCard(
        icon: Icons.favorite_rounded,
        title: 'Любимые треки',
        subtitle: favorites.isEmpty
            ? 'Отмечайте треки сердцем — они соберутся здесь'
            : '${favorites.length} ${_tracksWord(favorites.length)} в коллекции',
        tracks: favorites,
        onTap: () => favorites.isEmpty
            ? context.go('/library')
            : unawaited(play(favorites)),
      ),
    ];
    if (compact) {
      return Column(children: [cards[0], const SizedBox(height: 12), cards[1]]);
    }
    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tracks,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<UnifiedTrack> tracks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final covers = tracks
        .where((track) => track.artworkUrl != null)
        .take(4)
        .toList();
    return ResonancePressable(
      child: Material(
        color: ResonanceColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 84,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Row(
                  children: [
                    const Spacer(flex: 4),
                    for (final cover in covers)
                      Expanded(
                        flex: 2,
                        child: TrackArtwork(
                          track: cover,
                          size: 160,
                          borderRadius: 0,
                        ),
                      ),
                    if (covers.isEmpty) const Spacer(flex: 6),
                  ],
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ResonanceColors.surfaceHigh,
                        Color(0xF2151514),
                        Color(0x66151514),
                      ],
                      stops: [0, .45, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: ResonanceColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFB2ACA6),
                                fontSize: 12,
                              ),
                            ),
                          ],
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
}

class _SceneCard extends ConsumerWidget {
  const _SceneCard({required this.scene, required this.size});

  final _WaveScene scene;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wave = ref.watch(waveControllerProvider);
    final active = wave.active && wave.prompt == scene.prompt;
    return MediaCard(
      title: scene.label,
      subtitle: scene.subtitle,
      size: size,
      accent: scene.color,
      active: active,
      playing: active,
      loading: wave.loading && wave.prompt == scene.prompt,
      artwork: GradientArtwork(
        seed: scene.label,
        icon: scene.icon,
        label: scene.label,
        colors: [
          scene.color,
          Color.lerp(scene.color, const Color(0xFF07070A), .78)!,
        ],
      ),
      onTap: () {
        if (!wave.loading) unawaited(startWave(ref, scene.prompt));
      },
    );
  }
}

const _waveScenes = [
  _WaveScene(
    'Ваш день',
    'Знакомое + немного нового',
    Icons.center_focus_strong_rounded,
    'Мой персональный микс на сегодня: любимое и немного новых открытий',
    Color(0xFFFF6A43),
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
  _WaveScene(
    'Фокус',
    'Без слов и отвлечений',
    Icons.psychology_rounded,
    'Музыка для концентрации и работы, мало вокала',
    Color(0xFFE6B84A),
  ),
  _WaveScene(
    'Тренировка',
    'Громко и быстро',
    Icons.bolt_rounded,
    'Мощная энергичная музыка для тренировки',
    Color(0xFFFF4D8D),
  ),
];

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

class _PlaybackSignal extends StatelessWidget {
  const _PlaybackSignal({required this.state});

  final ResonancePlaybackState state;

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
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x990A0A0A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x40FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: ResonanceMotion.quick,
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: state.playing
                    ? ResonanceColors.primary
                    : ResonanceColors.muted,
                shape: BoxShape.circle,
                boxShadow: state.playing
                    ? const [BoxShadow(color: Color(0x88FF5538), blurRadius: 8)]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
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

class _WaveCommandCenter extends ConsumerStatefulWidget {
  const _WaveCommandCenter();

  @override
  ConsumerState<_WaveCommandCenter> createState() => _WaveCommandCenterState();
}

class _WaveCommandCenterState extends ConsumerState<_WaveCommandCenter> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() => startWave(ref, _controller.text);

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
