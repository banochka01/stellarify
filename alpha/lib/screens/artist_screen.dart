import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/artist/artist_api.dart';
import 'package:resonance/features/artist/artist_screen.dart' as core;
import 'package:resonance/features/platform/feature_flags.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/screens/track_row.dart';
import 'package:resonance_alpha/screens/tracklist_screen.dart';
import 'package:resonance_alpha/state.dart';

/// Separate names in «A, B feat. C».
List<String> artistNames(String artist) => core.splitArtists(artist);

/// Opens the page of the first artist in [artist] on the nearest navigator.
void openArtist(BuildContext context, String artist) {
  final name = artistNames(artist).firstOrNull ?? artist.trim();
  if (name.isEmpty) return;
  Navigator.of(context).push(alphaRoute<void>(ArtistScreen(artist: name)));
}

/// Tracks of one artist: the library first, then every connected catalog.
final artistTracksProvider = core.artistTracksProvider;

/// Releases, follow state and concerts; null when the service has none.
final _overviewProvider = FutureProvider.autoDispose
    .family<ArtistOverview?, String>((ref, artist) async {
      if (!ref.watch(featureEnabledProvider(FeatureFlag.artistPage))) {
        return null;
      }
      try {
        return await ref.watch(artistOverviewProvider(artist).future);
      } on Object {
        return null;
      }
    });

/// An artist as a poster: the name huge over a faded cover, then the
/// popular tracks, releases and concerts.
class ArtistScreen extends ConsumerStatefulWidget {
  const ArtistScreen({required this.artist, super.key});

  final String artist;

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  bool _all = false;
  bool? _following;

  Future<void> _toggleFollow(bool following) async {
    setState(() => _following = !following);
    try {
      await ref
          .read(artistApiProvider)
          .setFollowing(widget.artist, following: !following);
    } on Object {
      if (mounted) setState(() => _following = following);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = wide ? 48.0 : 20.0;
    final tracks = ref.watch(artistTracksProvider(widget.artist));
    final overview = ref.watch(_overviewProvider(widget.artist)).valueOrNull;
    final list = tracks.valueOrNull ?? const <UnifiedTrack>[];
    final top = overview?.topTracks.isNotEmpty == true
        ? _merge(overview!.topTracks, list)
        : list;
    final cover = top.where((t) => t.artworkUrl != null).firstOrNull;
    final accent = cover == null
        ? Pal.acid
        : ref.watch(trackAccentProvider(cover));
    final canFollow =
        overview != null &&
        ref.watch(featureEnabledProvider(FeatureFlag.artistFollow));
    final following = _following ?? overview?.following ?? false;
    final shown = _all ? top : top.take(10).toList();
    final nameSize = wide
        ? (widget.artist.length > 16 ? 72.0 : 112.0)
        : (widget.artist.length > 14 ? 40.0 : 58.0);

    return Scaffold(
      backgroundColor: Pal.stage,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                if (cover != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: .3,
                      child: ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Colors.transparent],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: TrackArtwork(
                            track: cover,
                            size: 640,
                            borderRadius: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 12, pad, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Knob(
                          icon: Icons.arrow_back_rounded,
                          size: 44,
                          tooltip: 'Назад',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        SizedBox(height: wide ? 110 : 64),
                        Text('АРТИСТ', style: Txt.mono(12, color: Pal.paper)),
                        const SizedBox(height: 8),
                        Text(
                          widget.artist,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Txt.display(nameSize),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          tracks.isLoading
                              ? 'Собираю треки…'
                              : '${top.length} ${plural(top.length, 'трек', 'трека', 'треков')}',
                          style: Txt.mono(13),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            Pill(
                              large: true,
                              active: true,
                              accent: accent,
                              icon: Icons.play_arrow_rounded,
                              label: 'Слушать',
                              onTap: top.isEmpty
                                  ? null
                                  : () =>
                                        run(context, () => playList(ref, top)),
                            ),
                            Pill(
                              large: true,
                              icon: Icons.blur_on_rounded,
                              label: 'Поток по артисту',
                              onTap: () => run(
                                context,
                                () => artistFlow(ref, widget.artist),
                              ),
                            ),
                            if (canFollow)
                              Pill(
                                large: true,
                                icon: following
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                label: following ? 'Слежу' : 'Следить',
                                onTap: () => run(
                                  context,
                                  () => _toggleFollow(following),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: const SliverToBoxAdapter(
              child: SectionHead(index: '01', title: 'Популярное'),
            ),
          ),
          if (tracks.isLoading && top.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (top.isEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverToBoxAdapter(
                child: Hollow(
                  title: 'Ничего не нашлось',
                  body: 'Каталоги не знают этого артиста или недоступны.',
                  action: Pill(
                    label: 'Ещё раз',
                    onTap: () =>
                        ref.invalidate(artistTracksProvider(widget.artist)),
                  ),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad - 12),
              sliver: SliverList.builder(
                itemCount: shown.length,
                itemBuilder: (context, index) => TrackRow(
                  track: shown[index],
                  index: index,
                  onTap: () =>
                      run(context, () => playList(ref, top, index: index)),
                ),
              ),
            ),
            if (top.length > shown.length)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Pill(
                      label: 'Все ${top.length}',
                      icon: Icons.expand_more_rounded,
                      onTap: () => setState(() => _all = true),
                    ),
                  ),
                ),
              ),
          ],
          if (overview != null && overview.releases.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 56, pad, 0),
              sliver: const SliverToBoxAdapter(
                child: SectionHead(index: '02', title: 'Релизы'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: wide ? 250 : 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  itemCount: overview.releases.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) => _ReleaseCard(
                    artist: widget.artist,
                    release: overview.releases[index],
                    size: wide ? 180 : 140,
                  ),
                ),
              ),
            ),
          ],
          if (overview != null && overview.concerts.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 48, pad, 0),
              sliver: SliverToBoxAdapter(
                child: SectionHead(
                  index: overview.releases.isNotEmpty ? '03' : '02',
                  title: 'Концерты',
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverList.list(
                children: [
                  for (final concert in overview.concerts.take(6))
                    _ConcertLine(concert: concert),
                ],
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 180)),
        ],
      ),
    );
  }
}

/// Service top tracks first, then the rest from the catalogs, without repeats.
List<UnifiedTrack> _merge(List<UnifiedTrack> top, List<UnifiedTrack> rest) {
  final seen = <String>{};
  return [
    for (final track in [...top, ...rest])
      if (seen.add('${track.normalizedArtist}|${track.normalizedTitle}')) track,
  ];
}

class _ReleaseCard extends ConsumerWidget {
  const _ReleaseCard({
    required this.artist,
    required this.release,
    required this.size,
  });

  final String artist;
  final ArtistRelease release;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = release.releasedAt?.year;
    return Press(
      scale: .97,
      onTap: () => Navigator.of(context).push(
        TracklistScreen.route(
          title: release.title,
          subtitle: [artist, release.typeLabel, ?year?.toString()].join(' · '),
          load: () async {
            final outcome = await ref.read(
              searchProvider('$artist ${release.title}').future,
            );
            final needle = artist.toLowerCase();
            return outcome.tracks
                .where((t) => t.artist.toLowerCase().contains(needle))
                .toList(growable: false);
          },
        ),
      ),
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: size,
                height: size,
                color: Pal.raised,
                child: release.artworkUrl == null
                    ? Center(child: Text('♪', style: Txt.display(size * .3)))
                    : Image.network(
                        release.artworkUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: (size * 2).round(),
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              release.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Txt.body(14, weight: 700),
            ),
            Text(
              [release.typeLabel, ?year?.toString()].join(' · '),
              style: Txt.mono(11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConcertLine extends StatelessWidget {
  const _ConcertLine({required this.concert});

  final ArtistConcert concert;

  @override
  Widget build(BuildContext context) {
    final date = concert.date;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Pal.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              date == null
                  ? '—'
                  : '${date.day.toString().padLeft(2, '0')}.'
                        '${date.month.toString().padLeft(2, '0')}.'
                        '${date.year % 100}',
              style: Txt.mono(13, color: Pal.paper),
            ),
          ),
          Expanded(
            child: Text(
              concert.place.isEmpty ? concert.country : concert.place,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Txt.body(16, weight: 650),
            ),
          ),
        ],
      ),
    );
  }
}
