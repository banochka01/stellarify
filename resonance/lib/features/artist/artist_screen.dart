import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/music_graph/music_graph.dart';
import 'package:resonance/features/player/track_action.dart';
import 'package:resonance/features/wave/wave_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/ambient.dart';
import 'package:resonance/shared/widgets/aurora_backdrop.dart';
import 'package:resonance/shared/widgets/playback_position.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

final _artistSplit = RegExp(
  r'\s*(?:,|&|/|\bfeat\.?|\bft\.?|\bx\b|\band\b|\bи\b)\s*',
  caseSensitive: false,
);

/// Отдельные имена исполнителей из строки вида «A, B feat. C».
List<String> splitArtists(String artist) => artist
    .split(_artistSplit)
    .map((name) => name.trim())
    .where((name) => name.isNotEmpty)
    .toList(growable: false);

String _norm(String value) => value.toLowerCase().replaceAll('ё', 'е').trim();

bool trackHasArtist(UnifiedTrack track, String artist) {
  final target = _norm(artist);
  return splitArtists(track.artist).any((name) => _norm(name) == target);
}

void openArtist(BuildContext context, String artist) {
  final name = splitArtists(artist).firstOrNull ?? artist.trim();
  if (name.isEmpty) return;
  unawaited(context.push('/artist/${Uri.encodeComponent(name)}'));
}

/// Треки исполнителя: локальная медиатека + поиск по подключённым каталогам.
final artistTracksProvider = FutureProvider.autoDispose
    .family<List<UnifiedTrack>, String>((ref, artist) async {
      final library = ref.read(libraryControllerProvider).valueOrNull;
      final local = [
        ...?library?.favorites,
        ...?library?.tracks,
      ].where((track) => trackHasArtist(track, artist));

      final registry = ref.read(providerRegistryProvider);
      final searches = <Future<List<UnifiedTrack>>>[
        for (final provider in const [
          MusicProvider.yandex,
          MusicProvider.soundcloud,
          MusicProvider.spotify,
          MusicProvider.vk,
        ])
          if (registry.catalogFor(provider) case final catalog?)
            catalog
                .searchTracks(artist, limit: 30)
                .timeout(const Duration(seconds: 12))
                .catchError((Object _) => const <UnifiedTrack>[]),
      ];
      final remote = (await Future.wait(searches)).expand((batch) => batch);
      final matching = remote.where((track) => trackHasArtist(track, artist));
      final tracks = const MusicGraphBuilder().canonicalize([
        ...local,
        ...matching,
      ]);
      if (tracks.isNotEmpty) ref.keepAlive();
      return tracks;
    });

class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({required this.artist, super.key});

  final String artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(artistTracksProvider(artist));
    final list = tracks.valueOrNull ?? const <UnifiedTrack>[];
    final cover = list.where((t) => t.artworkUrl != null).firstOrNull;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;
    final favorites =
        ref.watch(libraryControllerProvider).valueOrNull?.favoriteIds ??
        const <String>{};
    final liked = list.where((t) => favorites.contains(t.id)).length;

    return Material(
      color: ResonanceColors.background,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: compact ? 380 : 420,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null)
                    AuroraBackdrop(
                      track: cover,
                      intensity: 1.1,
                      animate: ref.watch(
                        playbackFrameProvider.select((s) => s.playing),
                      ),
                    )
                  else
                    const ColoredBox(color: Color(0xFF0B0810)),
                  if (cover?.artworkUrl case final url?)
                    Positioned.fill(
                      child: Opacity(
                        opacity: .16,
                        child: CachedNetworkImage(
                          imageUrl: highQualityArtworkUrl(url),
                          fit: BoxFit.cover,
                          color: Colors.black,
                          colorBlendMode: BlendMode.luminosity,
                          errorWidget: (_, _, _) => const SizedBox(),
                        ),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), ResonanceColors.background],
                        stops: [.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: SafeArea(
                      child: IconButton.filledTonal(
                        tooltip: 'Назад',
                        onPressed: () =>
                            context.canPop() ? context.pop() : context.go('/'),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                  ),
                  Positioned(
                    left: compact ? 20 : 40,
                    right: compact ? 20 : 40,
                    bottom: 28,
                    child: ResonanceEntrance(
                      child: Flex(
                        direction: compact ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: compact
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.end,
                        children: [
                          _ArtistAvatar(
                            track: cover,
                            name: artist,
                            size: compact ? 120 : 180,
                          ),
                          SizedBox(width: 28, height: compact ? 18 : 0),
                          Flexible(
                            fit: compact ? FlexFit.loose : FlexFit.tight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'ИСПОЛНИТЕЛЬ',
                                  style: TextStyle(
                                    color: ResonanceColors.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.7,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  artist,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: ResonanceFonts.display,
                                    fontSize: compact ? 34 : 58,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  tracks.isLoading
                                      ? 'Собираем дискографию…'
                                      : '${list.length} треков'
                                            '${liked > 0 ? ' · $liked в любимых' : ''}',
                                  style: const TextStyle(
                                    color: Color(0xFFC9BFD3),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!compact)
                            _ArtistActions(artist: artist, tracks: list),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (compact)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: _ArtistActions(artist: artist, tracks: list),
              ),
            ),
          ...switch (tracks) {
            AsyncData() when list.isEmpty => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'Не нашли треков этого исполнителя в подключённых источниках.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ResonanceColors.muted),
                  ),
                ),
              ),
            ],
            AsyncError() => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'Не удалось загрузить треки исполнителя.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ResonanceColors.muted),
                  ),
                ),
              ),
            ],
            _ when list.isEmpty => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
            _ => [
              _SectionTitle(compact: compact, title: 'Популярное'),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 28),
                sliver: SliverList.builder(
                  itemCount: list.length.clamp(0, 10),
                  itemBuilder: (context, index) => ResonanceEntrance(
                    delay: Duration(milliseconds: 30 * index),
                    child: _ArtistTrackRow(
                      index: index,
                      track: list[index],
                      queue: list,
                    ),
                  ),
                ),
              ),
              if (list.length > 10) ...[
                _SectionTitle(compact: compact, title: 'Ещё треки'),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 214,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 20 : 40,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: list.length - 10,
                      separatorBuilder: (_, _) => const SizedBox(width: 16),
                      itemBuilder: (context, index) => _ArtistTrackCard(
                        track: list[index + 10],
                        queue: list,
                      ),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          },
        ],
      ),
    );
  }
}

Future<void> _playFrom(
  WidgetRef ref,
  List<UnifiedTrack> queue,
  int index,
) async {
  final playable = playableQueueTracks(queue);
  if (playable.isEmpty) return;
  final start = playable.indexWhere((t) => t.id == queue[index].id);
  final service = await ref.read(playbackServiceProvider.future);
  await service.setQueue(
    playable,
    startIndex: start < 0 ? 0 : start,
    autoplay: true,
  );
}

/// Волна от артиста: стартует Wave с этим исполнителем как единственным
/// зерном, дальше подмешиваются похожие треки из подключённых каталогов.
Future<void> startArtistWave(
  BuildContext context,
  WidgetRef ref,
  String artist,
  List<UnifiedTrack> tracks,
) async {
  final messenger = ScaffoldMessenger.of(context);
  if (BackendEndpoint.displayValue.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Волна работает через сервер Resonance')),
    );
    return;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  final controller = container.read(waveControllerProvider.notifier);
  await controller.start(
    taste: [
      ...tracks.take(5),
      if (tracks.isEmpty)
        UnifiedTrack(
          id: 'artist-seed:$artist',
          title: artist,
          normalizedTitle: artist.toLowerCase(),
          artist: artist,
          normalizedArtist: artist.toLowerCase(),
        ),
    ],
    prompt: 'Похоже на $artist',
    discovery: .45,
  );
  final error = container.read(waveControllerProvider).error;
  messenger.showSnackBar(
    SnackBar(content: Text(error ?? 'Волна «$artist» запущена')),
  );
}

class _ArtistActions extends ConsumerWidget {
  const _ArtistActions({required this.artist, required this.tracks});

  final String artist;
  final List<UnifiedTrack> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CreamPlayButton(
          size: 60,
          playing: false,
          onPressed: tracks.isEmpty
              ? () {}
              : () => fireAndForget(() => _playFrom(ref, tracks, 0)),
        ),
        const SizedBox(width: 12),
        RoundControl(
          tooltip: 'Перемешать',
          icon: Icons.shuffle_rounded,
          size: 48,
          onPressed: tracks.isEmpty
              ? () {}
              : () => fireAndForget(() {
                  final shuffled = [...tracks]..shuffle();
                  return _playFrom(ref, shuffled, 0);
                }),
        ),
        const SizedBox(width: 12),
        _ArtistWaveButton(artist: artist, tracks: tracks),
      ],
    );
  }
}

class _ArtistWaveButton extends ConsumerWidget {
  const _ArtistWaveButton({required this.artist, required this.tracks});

  final String artist;
  final List<UnifiedTrack> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(
      waveControllerProvider.select((wave) => wave.loading),
    );
    return FilledButton.tonalIcon(
      onPressed: loading
          ? null
          : () => fireAndForget(
              () => startArtistWave(context, ref, artist, tracks),
            ),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: const StadiumBorder(),
      ),
      icon: loading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.waves_rounded),
      label: const Text('Волна артиста'),
    );
  }
}

class _ArtistAvatar extends StatelessWidget {
  const _ArtistAvatar({
    required this.track,
    required this.name,
    required this.size,
  });

  final UnifiedTrack? track;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: track == null
          ? CircleAvatar(
              backgroundColor: ResonanceColors.surfaceRaised,
              child: Text(
                name.characters.firstOrNull?.toUpperCase() ?? '?',
                style: TextStyle(
                  fontFamily: ResonanceFonts.display,
                  fontSize: size * .38,
                ),
              ),
            )
          : TrackArtwork(
              track: track!,
              size: size,
              borderRadius: size / 2,
              fallbackAsset: 'assets/images/resonance_fallback_cover.png',
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.compact, required this.title});

  final bool compact;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(compact ? 20 : 40, 24, 20, 12),
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: ResonanceFonts.display,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ArtistTrackRow extends ConsumerWidget {
  const _ArtistTrackRow({
    required this.index,
    required this.track,
    required this.queue,
  });

  final int index;
  final UnifiedTrack track;
  final List<UnifiedTrack> queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      playbackFrameProvider.select((s) => s.currentTrack?.id),
    );
    final active = current == track.id;
    final provider =
        track.preferredProvider ?? track.sources.firstOrNull?.provider;
    final duration = track.duration;
    return ResonancePressable(
      hoverScale: 1.004,
      hoverOffset: Offset.zero,
      child: Material(
        color: active ? const Color(0x1FB69CFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => fireAndForget(() => _playFrom(ref, queue, index)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: active
                      ? const Icon(
                          Icons.graphic_eq_rounded,
                          color: ResonanceColors.primary,
                          size: 18,
                        )
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontFamily: ResonanceFonts.mono,
                            color: ResonanceColors.muted,
                            fontSize: 12,
                          ),
                        ),
                ),
                TrackArtwork(
                  track: track,
                  size: 44,
                  borderRadius: 8,
                  fallbackAsset: 'assets/images/resonance_fallback_cover.png',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: active ? ResonanceColors.primary : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.album ?? track.artist,
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
                if (provider != null) ...[
                  ProviderBadge(provider: provider, compact: true),
                  const SizedBox(width: 12),
                ],
                if (duration != null)
                  Text(
                    '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontFamily: ResonanceFonts.mono,
                      color: ResonanceColors.muted,
                      fontSize: 12,
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

class _ArtistTrackCard extends ConsumerWidget {
  const _ArtistTrackCard({required this.track, required this.queue});

  final UnifiedTrack track;
  final List<UnifiedTrack> queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResonancePressable(
      hoverScale: 1.03,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            fireAndForget(() => _playFrom(ref, queue, queue.indexOf(track))),
        child: SizedBox(
          width: 156,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrackArtwork(
                track: track,
                size: 156,
                borderRadius: 14,
                fallbackAsset: 'assets/images/resonance_fallback_cover.png',
              ),
              const SizedBox(height: 10),
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
