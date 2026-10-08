import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/artist/artist_screen.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/player/track_action.dart';
import 'package:resonance/features/recap/listening_recap.dart';
import 'package:resonance/features/rooms/room_controller.dart';
import 'package:resonance/features/wave/wave_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/ambient.dart';
import 'package:resonance/shared/widgets/aurora_backdrop.dart';
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
    final favorites = library?.favorites ?? const <UnifiedTrack>[];
    final forYou = <String, UnifiedTrack>{
      for (final item in [
        ...state.queue.reversed,
        ...favorites,
        ...?library?.tracks,
      ])
        item.id: item,
    }.values.take(16).toList(growable: false);
    final artists = _topArtists([
      ...favorites,
      ...state.queue,
      ...?library?.tracks,
    ]);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 1000;
        final gutter = compact ? 16.0 : 32.0;
        final heroHeight = (constraints.maxHeight * .46).clamp(
          compact ? 420.0 : 340.0,
          compact ? 520.0 : 440.0,
        );
        var section = 0;
        Widget reveal(Widget child) => ResonanceEntrance(
          delay: Duration(milliseconds: 70 * section++),
          child: child,
        );
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: heroHeight,
                child: _WaveHero(
                  track: track,
                  state: state,
                  compact: compact,
                  gutter: gutter,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
              sliver: SliverToBoxAdapter(
                child: reveal(
                  _QuickTiles(
                    compact: compact,
                    history: state.queue.reversed.toList(growable: false),
                    favorites: favorites,
                    animate: state.playing,
                  ),
                ),
              ),
            ),
            if (forYou.isNotEmpty) ...[
              _HomeSectionTitle(title: 'Для вас', gutter: gutter),
              SliverToBoxAdapter(
                child: reveal(
                  _Carousel(
                    gutter: gutter,
                    height: compact ? 200 : 228,
                    itemCount: forYou.length,
                    itemBuilder: (context, index) => _TrackCard(
                      track: forYou[index],
                      size: compact ? 136 : 160,
                    ),
                  ),
                ),
              ),
            ],
            if (artists.isNotEmpty) ...[
              _HomeSectionTitle(title: 'Ваши артисты', gutter: gutter),
              SliverToBoxAdapter(
                child: reveal(
                  _Carousel(
                    gutter: gutter,
                    height: compact ? 160 : 186,
                    itemCount: artists.length,
                    itemBuilder: (context, index) => _ArtistBubble(
                      name: artists[index].$1,
                      track: artists[index].$2,
                      size: compact ? 108 : 132,
                    ),
                  ),
                ),
              ),
            ],
            _HomeSectionTitle(title: 'Настроение волны', gutter: gutter),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 48),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: reveal(const _WaveCommandCenter()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Самые частые исполнители в медиатеке и очереди, с обложкой для аватара.
List<(String, UnifiedTrack)> _topArtists(List<UnifiedTrack> tracks) {
  final counts = <String, int>{};
  final names = <String, String>{};
  final covers = <String, UnifiedTrack>{};
  final demo = demoTrack.artist.toLowerCase();
  for (final track in tracks) {
    for (final name in splitArtists(track.artist)) {
      final key = name.toLowerCase();
      if (key == demo) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      names[key] ??= name;
      if (track.artworkUrl != null) covers[key] ??= track;
      covers[key] ??= track;
    }
  }
  final keys = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return [for (final key in keys.take(14)) (names[key]!, covers[key]!)];
}

/// «Моя волна»: живой фон по обложке текущего трека, крупный заголовок,
/// парящая обложка и главная кнопка запуска.
class _WaveHero extends ConsumerWidget {
  const _WaveHero({
    required this.track,
    required this.state,
    required this.compact,
    required this.gutter,
  });

  final UnifiedTrack track;
  final ResonancePlaybackState state;
  final bool compact;
  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wave = ref.watch(waveControllerProvider);
    final hasCustomBackground =
        ref.watch(appearanceControllerProvider).backgroundPath != null;
    final title = Text(
      'Моя\nволна',
      style: TextStyle(
        fontFamily: ResonanceFonts.display,
        fontSize: compact ? 52 : 84,
        height: .92,
        fontWeight: FontWeight.w800,
        letterSpacing: compact ? -2 : -3.5,
        shadows: const [Shadow(color: Color(0x66000000), blurRadius: 30)],
      ),
    );
    final nowPlaying = ResonanceAnimatedSwap(
      alignment: AlignmentDirectional.topStart,
      child: Column(
        key: ValueKey('hero-track-${track.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                wave.active ? Icons.graphic_eq_rounded : Icons.waves_rounded,
                size: 16,
                color: const Color(0xFFE8DDF2),
              ),
              const SizedBox(width: 6),
              Text(
                wave.active ? 'Волна играет' : 'Обычная',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Text('  ·  ', style: TextStyle(color: Color(0xFFD9CFE3))),
                Flexible(child: _ArtistLink(artist: track.artist)),
              ],
            ),
          ),
          if (_waveReason(track) case final reason?) ...[
            const SizedBox(height: 10),
            _ReasonPill(reason: reason),
          ],
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!hasCustomBackground)
          // Фон растворяется книзу, чтобы hero перетекал в ленту без шва.
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, .62, 1],
            ).createShader(bounds),
            child: AuroraBackdrop(track: track, animate: state.playing),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, compact ? 24 : 36, gutter, 20),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FloatingCover(
                          track: track,
                          size: 116,
                          animate: state.playing,
                        ),
                        const Spacer(),
                        _HeroPlay(state: state, size: 68),
                      ],
                    ),
                    const Spacer(),
                    ResonanceEntrance(child: title),
                    const SizedBox(height: 16),
                    nowPlaying,
                    const SizedBox(height: 14),
                    _PlaybackSignal(state: state, compact: true),
                  ],
                )
              : Row(
                  children: [
                    _FloatingCover(
                      track: track,
                      size: 200,
                      animate: state.playing,
                    ),
                    const SizedBox(width: 44),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ResonanceEntrance(child: title),
                          const SizedBox(height: 20),
                          nowPlaying,
                          const SizedBox(height: 16),
                          _PlaybackSignal(state: state),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _HeroPlay(state: state, size: 84),
                        const SizedBox(height: 18),
                        const _HeroActions(),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _HeroPlay extends ConsumerWidget {
  const _HeroPlay({required this.state, required this.size});

  final ResonancePlaybackState state;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Breathing(
      active: state.playing,
      child: CreamPlayButton(
        size: size,
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
    );
  }
}

/// Мягкое «дыхание»: элемент чуть пульсирует, пока музыка играет.
class _Breathing extends StatefulWidget {
  const _Breathing({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: 1.05,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));

  void _sync() {
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (widget.active && !reduced) {
      if (!_controller.isAnimating) {
        unawaited(_controller.repeat(reverse: true));
      }
    } else {
      unawaited(_controller.animateTo(0, duration: ResonanceMotion.standard));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Breathing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Обложка текущего трека, медленно парящая над фоном.
class _FloatingCover extends StatefulWidget {
  const _FloatingCover({
    required this.track,
    required this.size,
    required this.animate,
  });

  final UnifiedTrack track;
  final double size;
  final bool animate;

  @override
  State<_FloatingCover> createState() => _FloatingCoverState();
}

class _FloatingCoverState extends State<_FloatingCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  // Декоративный цикл живёт, только пока играет музыка: на паузе
  // кадр застывает, а при отключённых анимациях не запускается вовсе.
  void _syncLoop() {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(_FloatingCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncLoop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.size * .14;
    final cover = ResonanceTrackSwap(
      child: DecoratedBox(
        key: ValueKey('cover-${widget.track.id}'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x8C000000),
              blurRadius: 40,
              offset: Offset(0, 22),
            ),
          ],
        ),
        child: TrackArtwork(
          track: widget.track,
          size: widget.size,
          borderRadius: radius,
          fallbackAsset: 'assets/images/resonance_fallback_cover.png',
        ),
      ),
    );
    return GestureDetector(
      onTap: () => unawaited(context.push('/player')),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value * math.pi * 2;
            return Transform.translate(
              offset: Offset(0, math.sin(t) * 6),
              child: Transform.rotate(
                angle: math.sin(t + 1) * .018,
                child: child,
              ),
            );
          },
          child: cover,
        ),
      ),
    );
  }
}

class _ArtistLink extends StatefulWidget {
  const _ArtistLink({required this.artist});

  final String artist;

  @override
  State<_ArtistLink> createState() => _ArtistLinkState();
}

class _ArtistLinkState extends State<_ArtistLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => openArtist(context, widget.artist),
        child: Text(
          widget.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: _hovered ? ResonanceColors.text : const Color(0xFFBFB4CB),
            decoration: _hovered ? TextDecoration.underline : null,
          ),
        ),
      ),
    );
  }
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({required this.title, required this.gutter});

  final String title;
  final double gutter;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: EdgeInsets.fromLTRB(gutter, 30, gutter, 14),
    sliver: SliverToBoxAdapter(
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: ResonanceFonts.display,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -.4,
        ),
      ),
    ),
  );
}

class _Carousel extends StatelessWidget {
  const _Carousel({
    required this.gutter,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  final double gutter;
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 6),
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(width: 16),
      itemBuilder: itemBuilder,
    ),
  );
}

/// Плитки «История», «Любимые» и «Итоги»: коллаж обложек медленно
/// уплывает влево.
class _QuickTiles extends ConsumerWidget {
  const _QuickTiles({
    required this.compact,
    required this.history,
    required this.favorites,
    required this.animate,
  });

  final bool animate;
  final bool compact;
  final List<UnifiedTrack> history;
  final List<UnifiedTrack> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recap = ref
        .watch(listeningRecapProvider(RecapPeriod.week))
        .valueOrNull;
    final tiles = [
      _QuickTile(
        icon: Icons.history_rounded,
        title: 'История',
        subtitle: 'Недавно прослушанные треки',
        tracks: history,
        animate: animate,
        onTap: () => unawaited(context.push('/player')),
      ),
      _QuickTile(
        icon: Icons.favorite_rounded,
        title: 'Любимые треки',
        subtitle: favorites.isEmpty
            ? 'Отмечайте сердцем то, что нравится'
            : '${favorites.length} в коллекции',
        tracks: favorites,
        animate: animate,
        onTap: () => context.go('/library'),
      ),
      // «Итоги» появляются, когда в истории есть хотя бы одно прослушивание.
      if (recap != null && !recap.empty)
        _QuickTile(
          icon: Icons.insights_rounded,
          title: 'Итоги недели',
          subtitle: '${recap.minutes} мин · ${recap.persona}',
          tracks: [for (final item in recap.topTracks) item.track],
          animate: animate,
          onTap: () => context.go('/recap'),
        ),
    ];
    if (compact) {
      return Column(
        children: [
          for (final (index, tile) in tiles.indexed) ...[
            if (index > 0) const SizedBox(height: 12),
            tile,
          ],
        ],
      );
    }
    return Row(
      children: [
        for (final (index, tile) in tiles.indexed) ...[
          if (index > 0) const SizedBox(width: 16),
          Expanded(child: tile),
        ],
      ],
    );
  }
}

class _QuickTile extends StatefulWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tracks,
    required this.onTap,
    required this.animate,
  });

  final bool animate;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<UnifiedTrack> tracks;
  final VoidCallback onTap;

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile>
    with SingleTickerProviderStateMixin {
  static const _tileHeight = 84.0;
  static const _coverWidth = _tileHeight * 2.4;
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );

  // Декоративный цикл живёт, только пока играет музыка: на паузе
  // кадр застывает, а при отключённых анимациях не запускается вовсе.
  void _syncLoop() {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      unawaited(_drift.repeat());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(_QuickTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncLoop();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final covers = widget.tracks
        .where((t) => t.artworkUrl != null)
        .take(8)
        .toList(growable: false);
    final strip = covers.length * _coverWidth;
    return ResonancePressable(
      hoverScale: 1.012,
      child: Material(
        color: ResonanceColors.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            height: _tileHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (covers.isNotEmpty)
                  ClipRect(
                    child: AnimatedBuilder(
                      animation: _drift,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(-_drift.value * strip, 0),
                        child: child,
                      ),
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        maxWidth: double.infinity,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < 3; i++)
                              for (final track in covers)
                                SizedBox(
                                  width: _coverWidth,
                                  height: _tileHeight,
                                  child: CachedNetworkImage(
                                    imageUrl: highQualityArtworkUrl(
                                      track.artworkUrl!,
                                      targetSize: 400,
                                    ),
                                    fit: BoxFit.cover,
                                    memCacheWidth: 400,
                                    errorWidget: (_, _, _) => const SizedBox(),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xF0100C15),
                        Color(0x99100C15),
                        Color(0x40100C15),
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
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Color(0x26FFFFFF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.icon, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFC6BBD1),
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

/// Карточка трека с появляющейся при наведении кнопкой запуска.
class _TrackCard extends ConsumerStatefulWidget {
  const _TrackCard({required this.track, required this.size});

  final UnifiedTrack track;
  final double size;

  @override
  ConsumerState<_TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends ConsumerState<_TrackCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final active =
        ref.watch(playbackFrameProvider.select((s) => s.currentTrack?.id)) ==
        track.id;
    final lit = _hovered || active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ResonancePressable(
        hoverScale: 1.03,
        child: GestureDetector(
          onTap: () => unawaited(playTrackOrOpenOfficial(ref, track)),
          child: SizedBox(
            width: widget.size,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AnimatedContainer(
                      duration: ResonanceMotion.standard,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: lit
                                ? const Color(0x55B69CFF)
                                : const Color(0x40000000),
                            blurRadius: _hovered ? 26 : 14,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: TrackArtwork(
                        track: track,
                        size: widget.size,
                        borderRadius: 14,
                        fallbackAsset:
                            'assets/images/resonance_fallback_cover.png',
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: AnimatedOpacity(
                        duration: ResonanceMotion.quick,
                        opacity: lit ? 1 : 0,
                        child: AnimatedSlide(
                          duration: ResonanceMotion.standard,
                          curve: ResonanceMotion.curve,
                          offset: lit ? Offset.zero : const Offset(0, .3),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: ResonanceColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Icon(
                              active
                                  ? Icons.graphic_eq_rounded
                                  : Icons.play_arrow_rounded,
                              color: const Color(0xFF14101A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                _ArtistLink(artist: track.artist),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistBubble extends StatelessWidget {
  const _ArtistBubble({
    required this.name,
    required this.track,
    required this.size,
  });

  final String name;
  final UnifiedTrack track;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ResonancePressable(
      hoverScale: 1.05,
      child: GestureDetector(
        onTap: () => openArtist(context, name),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: size,
            child: Column(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x59000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: TrackArtwork(
                    track: track,
                    size: size,
                    borderRadius: size / 2,
                    fallbackAsset: 'assets/images/resonance_fallback_cover.png',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

/// Действия hero на десктопе: вход в Stage и оценка Wave.
/// Перемотка и переключение треков — в нижнем плеере.
class _HeroActions extends ConsumerWidget {
  const _HeroActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wave = ref.watch(waveControllerProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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

String? _waveReason(UnifiedTrack track) {
  for (final source in track.sources) {
    final reason = source.metadata['waveReason'];
    if (reason is String && reason.trim().isNotEmpty) return reason.trim();
  }
  return null;
}
