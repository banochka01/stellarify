import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/artist/artist_catalog.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/player/track_action.dart';
import 'package:resonance/features/wave/wave_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/ambient_backdrop.dart';
import 'package:resonance/shared/widgets/media_cards.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';

class ArtistScreen extends ConsumerStatefulWidget {
  const ArtistScreen({required this.name, super.key});

  final String name;

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  String? _loadingId;

  ArtistTrackResolver get _resolver =>
      ArtistTrackResolver(ref.read(providerRegistryProvider));

  Future<List<UnifiedTrack>> _known() => ref
      .read(artistPlayableTracksProvider(widget.name).future)
      .onError((_, _) => const <UnifiedTrack>[]);

  Future<void> _guard(String id, Future<void> Function() action) async {
    if (_loadingId != null) return;
    setState(() => _loadingId = id);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _loadingId = null);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _playInfo(ArtistTrackInfo info) => _guard(info.id, () async {
    final track = await _resolver.resolve(info, known: await _known());
    if (track == null) {
      _notify('«${info.title}» не нашёлся в подключённых источниках.');
      return;
    }
    await playTrackOrOpenOfficial(ref, track);
  });

  Future<void> _playTrack(UnifiedTrack track) =>
      _guard(track.id, () => playTrackOrOpenOfficial(ref, track));

  Future<void> _playAll(
    List<ArtistTrackInfo> infos, {
    bool shuffle = false,
    String id = 'all',
  }) => _guard(shuffle ? 'shuffle' : id, () async {
    final known = await _known();
    var tracks = infos.isEmpty
        ? known
        : await _resolver.resolveAll(infos, known: known);
    if (tracks.isEmpty) tracks = known;
    tracks = playableQueueTracks(tracks);
    if (tracks.isEmpty) {
      _notify('Подключите источник в настройках, чтобы слушать этого артиста.');
      return;
    }
    if (shuffle) tracks = [...tracks]..shuffle(math.Random());
    final service = await ref.read(playbackServiceProvider.future);
    await service.setQueue(tracks, autoplay: true);
  });

  Future<void> _startWave(String name) => _guard('wave', () async {
    final favorites =
        ref.read(libraryControllerProvider).valueOrNull?.favorites ?? const [];
    await ref
        .read(waveControllerProvider.notifier)
        .start(
          taste: favorites,
          prompt: 'Музыка в духе $name и похожих артистов',
        );
    final wave = ref.read(waveControllerProvider);
    _notify(wave.error ?? 'Волна по артисту $name запущена');
  });

  Future<void> _openAlbum(ArtistAlbumInfo album, ArtworkPalette palette) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 760),
        builder: (context) => _AlbumSheet(
          album: album,
          palette: palette,
          artistName: widget.name,
          onPlay: (tracks, info) async {
            Navigator.of(context).pop();
            if (info != null) {
              await _playInfo(info);
            } else {
              await _playAll(tracks, id: album.id);
            }
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final profileValue = ref.watch(artistProfileProvider(widget.name));
    final playableValue = ref.watch(artistPlayableTracksProvider(widget.name));
    final profile = profileValue.valueOrNull;
    final playable = playableValue.valueOrNull ?? const <UnifiedTrack>[];
    final library = libraryTracksByArtist(
      ref.watch(libraryControllerProvider).valueOrNull,
      widget.name,
    );
    final playback =
        ref.watch(playbackStateProvider).valueOrNull ??
        const ResonancePlaybackState();
    final loading = profileValue.isLoading || playableValue.isLoading;
    final name = profile?.name ?? widget.name;
    final picture =
        profile?.pictureUrl ??
        playable.map((track) => track.artworkUrl).nonNulls.firstOrNull;
    final palette = watchArtworkPalette(ref, picture);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    final gutter = compact ? 18.0 : 34.0;
    final cardSize = compact ? 148.0 : 172.0;

    final topInfos = profile?.topTracks ?? const <ArtistTrackInfo>[];
    final albums =
        profile?.albums.where((album) => !album.isSingle).toList() ?? const [];
    final singles =
        profile?.albums.where((album) => album.isSingle).toList() ?? const [];
    final providers = {
      for (final track in playable) ...track.sources.map((s) => s.provider),
    }.where((p) => p != MusicProvider.youtube).toList();
    final nothing =
        !loading &&
        topInfos.isEmpty &&
        playable.isEmpty &&
        (profile?.albums.isEmpty ?? true);

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: compact ? 760 : 560,
          child: AmbientBackdrop(palette: palette, imageUrl: picture),
        ),
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _ArtistHeader(
                name: name,
                picture: picture,
                palette: palette,
                compact: compact,
                gutter: gutter,
                fans: profile?.fans,
                releases: profile?.albums.length,
                providers: providers,
                loadingId: _loadingId,
                onPlayAll: () => unawaited(_playAll(topInfos)),
                onShuffle: () => unawaited(_playAll(topInfos, shuffle: true)),
                onWave: () => unawaited(_startWave(name)),
              ),
            ),
            if (loading && topInfos.isEmpty && playable.isEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 0),
                sliver: SliverToBoxAdapter(
                  child: _ShelfSkeleton(size: cardSize),
                ),
              ),
            if (nothing)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 0),
                sliver: SliverToBoxAdapter(
                  child: _EmptyArtist(
                    name: name,
                    onSearch: () => context.go('/search'),
                  ),
                ),
              ),
            if (topInfos.isNotEmpty)
              _shelf(gutter, 'Популярные', cardSize, topInfos.length, (
                context,
                index,
              ) {
                final info = topInfos[index];
                final active = _isCurrent(playback, info.title, info.artist);
                return MediaCard(
                  title: info.title,
                  subtitle: info.album ?? name,
                  artworkUrl: info.artworkUrl,
                  size: cardSize,
                  accent: palette.accent,
                  active: active,
                  playing: playback.playing,
                  loading: _loadingId == info.id,
                  badge: index < 3 ? _RankBadge(rank: index + 1) : null,
                  onTap: () => active
                      ? unawaited(_togglePlayback(playback))
                      : unawaited(_playInfo(info)),
                );
              })
            else if (playable.isNotEmpty)
              _shelf(
                gutter,
                'Треки',
                cardSize,
                math.min(playable.length, 20),
                (context, index) =>
                    _trackCard(playable[index], playback, palette, cardSize),
              ),
            if (albums.isNotEmpty)
              _albumShelf(gutter, 'Альбомы', albums, cardSize, palette),
            if (singles.isNotEmpty)
              _albumShelf(gutter, 'Синглы и EP', singles, cardSize, palette),
            if (library.isNotEmpty)
              _shelf(
                gutter,
                'В вашей медиатеке',
                cardSize,
                library.length,
                (context, index) =>
                    _trackCard(library[index], playback, palette, cardSize),
              ),
            if (profile?.related.isNotEmpty ?? false)
              _shelf(
                gutter,
                'Похожие артисты',
                cardSize,
                profile!.related.length,
                (context, index) {
                  final artist = profile.related[index];
                  return MediaCard(
                    title: artist.name,
                    subtitle: artist.fans == null
                        ? 'Артист'
                        : '${compactCount(artist.fans!)} ${_fansWord(artist.fans!)}',
                    artworkUrl: artist.pictureUrl,
                    size: cardSize,
                    circular: true,
                    accent: palette.accent,
                    onTap: () => openArtist(context, artist.name),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ],
    );
  }

  Widget _trackCard(
    UnifiedTrack track,
    ResonancePlaybackState playback,
    ArtworkPalette palette,
    double size,
  ) {
    final active = playback.currentTrack?.id == track.id;
    final provider =
        track.preferredProvider ?? track.sources.firstOrNull?.provider;
    return MediaCard(
      title: track.title,
      subtitle: track.album ?? track.artist,
      artworkUrl: track.artworkUrl,
      size: size,
      accent: palette.accent,
      active: active,
      playing: playback.playing,
      loading: _loadingId == track.id,
      badge: provider == null
          ? null
          : ProviderBadge(provider: provider, compact: true),
      onTap: () => active
          ? unawaited(_togglePlayback(playback))
          : unawaited(_playTrack(track)),
    );
  }

  Future<void> _togglePlayback(ResonancePlaybackState state) async {
    final service = await ref.read(playbackServiceProvider.future);
    await (state.playing ? service.pause() : service.play());
  }

  Widget _albumShelf(
    double gutter,
    String title,
    List<ArtistAlbumInfo> albums,
    double size,
    ArtworkPalette palette,
  ) => _shelf(gutter, title, size, albums.length, (context, index) {
    final album = albums[index];
    return MediaCard(
      title: album.title,
      subtitle: _albumSubtitle(album),
      artworkUrl: album.artworkUrl,
      size: size,
      accent: palette.accent,
      loading: _loadingId == album.id,
      onTap: () => unawaited(_openAlbum(album, palette)),
    );
  });

  Widget _shelf(
    double gutter,
    String title,
    double size,
    int count,
    IndexedWidgetBuilder builder,
  ) => SliverPadding(
    padding: EdgeInsets.only(top: 26),
    sliver: SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: ShelfHeader(title: title),
          ),
          MediaShelf(
            itemCount: count,
            height: size + 62,
            itemWidth: size,
            padding: EdgeInsets.symmetric(horizontal: gutter),
            itemBuilder: builder,
          ),
        ],
      ),
    ),
  );
}

bool _isCurrent(ResonancePlaybackState state, String title, String artist) {
  final current = state.currentTrack;
  if (current == null) return false;
  return normalizeTitleKey(current.title) == normalizeTitleKey(title) &&
      artistCredits(current.artist).any(
        (credit) => normalizeArtistKey(credit) == normalizeArtistKey(artist),
      );
}

String _albumSubtitle(ArtistAlbumInfo album) {
  final kind = switch (album.type) {
    'single' => 'Сингл',
    'ep' => 'EP',
    'compilation' => 'Сборник',
    _ => 'Альбом',
  };
  final year = album.releaseDate?.year;
  return year == null ? kind : '$year · $kind';
}

String _fansWord(int count) {
  if (count >= 1000) return 'поклонников';
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return 'поклонник';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'поклонника';
  }
  return 'поклонников';
}

class _ArtistHeader extends StatelessWidget {
  const _ArtistHeader({
    required this.name,
    required this.picture,
    required this.palette,
    required this.compact,
    required this.gutter,
    required this.fans,
    required this.releases,
    required this.providers,
    required this.loadingId,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onWave,
  });

  final String name;
  final Uri? picture;
  final ArtworkPalette palette;
  final bool compact;
  final double gutter;
  final int? fans;
  final int? releases;
  final List<MusicProvider> providers;
  final String? loadingId;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final VoidCallback onWave;

  @override
  Widget build(BuildContext context) {
    final avatar = compact ? 168.0 : 224.0;
    final stats = [
      if (fans != null) '${compactCount(fans!)} ${_fansWord(fans!)}',
      if (releases != null && releases! > 0) '$releases релизов',
    ];
    final info = Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 16, color: palette.accent),
            const SizedBox(width: 6),
            const Text(
              'АРТИСТ',
              style: TextStyle(
                color: ResonanceColors.text,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: ResonanceColors.text,
            fontSize: compact ? 40 : 64,
            height: .95,
            fontWeight: FontWeight.w900,
            letterSpacing: compact ? -1.6 : -2.8,
          ),
        ),
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            stats.join(' · '),
            style: const TextStyle(
              color: Color(0xFFC9C3BC),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: compact ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: loadingId == null ? onPlayAll : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0B0B0B),
                disabledBackgroundColor: Colors.white.withValues(alpha: .7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              icon: loadingId == 'all'
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0B0B0B),
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: const Text('Слушать все'),
            ),
            _RoundAction(
              tooltip: 'Перемешать',
              icon: Icons.shuffle_rounded,
              loading: loadingId == 'shuffle',
              onPressed: loadingId == null ? onShuffle : null,
            ),
            _RoundAction(
              tooltip: 'Волна по артисту',
              icon: Icons.waves_rounded,
              loading: loadingId == 'wave',
              onPressed: loadingId == null ? onWave : null,
            ),
          ],
        ),
        if (providers.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final provider in providers)
                ProviderBadge(provider: provider, compact: true),
            ],
          ),
        ],
      ],
    );

    final portrait = Hero(
      tag: 'artist-$name',
      child: Container(
        width: avatar,
        height: avatar,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: .14),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: .38),
              blurRadius: 60,
              spreadRadius: 4,
            ),
            const BoxShadow(
              color: Color(0x80000000),
              blurRadius: 30,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: ClipOval(
          child: ArtworkImage(
            url: picture,
            seed: name,
            size: avatar,
            icon: Icons.person_rounded,
          ),
        ),
      ),
    );

    return SizedBox(
      height: compact ? 560 : 400,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Назад',
                        onPressed: () =>
                            context.canPop() ? context.pop() : context.go('/'),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: .28),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ResonanceColors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ResonanceEntrance(
                    child: compact
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                portrait,
                                const SizedBox(height: 20),
                                info,
                              ],
                            ),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              portrait,
                              const SizedBox(width: 34),
                              Expanded(child: info),
                            ],
                          ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      fixedSize: const Size.square(50),
      backgroundColor: Colors.white.withValues(alpha: .08),
      side: BorderSide(color: Colors.white.withValues(alpha: .16)),
    ),
    icon: loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 21),
  );
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      '#$rank',
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
    ),
  );
}

class _ShelfSkeleton extends StatelessWidget {
  const _ShelfSkeleton({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 180,
        height: 24,
        decoration: BoxDecoration(
          color: ResonanceColors.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: size,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(width: 16),
          itemBuilder: (_, index) => _Pulse(
            delay: index * 120,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: ResonanceColors.surfaceRaised,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _Pulse extends StatelessWidget {
  const _Pulse({required this.child, required this.delay});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: .45, end: 1),
    duration: ResonanceMotion.durationOf(
      context,
      Duration(milliseconds: 600 + delay),
    ),
    curve: Curves.easeInOut,
    builder: (context, value, child) => Opacity(opacity: value, child: child),
    child: child,
  );
}

class _EmptyArtist extends StatelessWidget {
  const _EmptyArtist({required this.name, required this.onSearch});

  final String name;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: ResonanceColors.surface.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ResonanceColors.border),
    ),
    child: Row(
      children: [
        const Icon(Icons.travel_explore_rounded, color: ResonanceColors.muted),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Пока не нашли треков $name. Подключите источник в настройках или поищите вручную.',
            style: const TextStyle(color: ResonanceColors.muted, height: 1.4),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(onPressed: onSearch, child: const Text('Поиск')),
      ],
    ),
  );
}

class _AlbumSheet extends ConsumerWidget {
  const _AlbumSheet({
    required this.album,
    required this.palette,
    required this.artistName,
    required this.onPlay,
  });

  final ArtistAlbumInfo album;
  final ArtworkPalette palette;
  final String artistName;
  final Future<void> Function(List<ArtistTrackInfo> all, ArtistTrackInfo? one)
  onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(artistAlbumProvider(album.id));
    final tracks = details.valueOrNull?.tracks ?? const <ArtistTrackInfo>[];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      maxChildSize: .94,
      minChildSize: .4,
      builder: (context, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: Stack(
          children: [
            Positioned.fill(
              child: AmbientBackdrop(
                palette: palette,
                imageUrl: album.artworkUrl,
                ribbons: false,
                intensity: .7,
                fadeTo: ResonanceColors.surface,
              ),
            ),
            ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 40),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox.square(
                        dimension: 132,
                        child: ArtworkImage(
                          url: album.artworkUrl,
                          seed: album.title,
                          size: 132,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _albumSubtitle(album).toUpperCase(),
                            style: const TextStyle(
                              color: ResonanceColors.text,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            album.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ResonanceColors.text,
                              fontSize: 28,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            artistName,
                            style: const TextStyle(
                              color: Color(0xFFC9C3BC),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: tracks.isEmpty
                                ? null
                                : () => unawaited(onPlay(tracks, null)),
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.accent,
                              foregroundColor: palette.onAccent,
                            ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Слушать'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (details.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (tracks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Не удалось загрузить треклист.',
                      style: TextStyle(color: ResonanceColors.muted),
                    ),
                  )
                else
                  for (var i = 0; i < tracks.length; i++)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: SizedBox(
                        width: 28,
                        child: Text(
                          '${i + 1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ResonanceColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        tracks[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ResonanceColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        tracks[i].artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ResonanceColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Text(
                        _duration(tracks[i].duration),
                        style: const TextStyle(color: ResonanceColors.muted),
                      ),
                      onTap: () => unawaited(onPlay(tracks, tracks[i])),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _duration(Duration? value) {
  if (value == null) return '';
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${value.inMinutes}:$seconds';
}
