import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/artist/artist_api.dart';
import 'package:resonance/features/platform/feature_api.dart';
import 'package:resonance/features/platform/feature_flags.dart';
import 'package:resonance/features/platform/feature_playback.dart';
import 'package:resonance/features/platform/feature_views.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Artist page 2.0 block: follow releases, new-release badge, releases,
/// clips, concerts and set-lists. Embedded into [ArtistScreen]; renders
/// nothing when `artists.page2` is off or the server lacks the endpoint.
class ArtistOverviewSection extends ConsumerStatefulWidget {
  const ArtistOverviewSection({required this.artist, super.key});

  final String artist;

  @override
  ConsumerState<ArtistOverviewSection> createState() =>
      _ArtistOverviewSectionState();
}

class _ArtistOverviewSectionState extends ConsumerState<ArtistOverviewSection> {
  bool? _following;
  bool _busy = false;
  bool _markedSeen = false;

  Future<void> _toggleFollow(ArtistOverview overview) async {
    final next = !(_following ?? overview.following);
    setState(() {
      _following = next;
      _busy = true;
    });
    try {
      await ref
          .read(artistApiProvider)
          .setFollowing(widget.artist, following: next);
      ref.invalidate(unreadReleasesProvider);
      if (mounted) {
        showFeatureSnack(
          context,
          next
              ? 'Сообщим о новых релизах ${widget.artist}'
              : 'Вы больше не следите за релизами',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _following = !next);
        showFeatureSnack(context, error.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(featureEnabledProvider(FeatureFlag.artistPage))) {
      return const SizedBox.shrink();
    }
    final overview = ref.watch(artistOverviewProvider(widget.artist));
    final value = overview.valueOrNull;
    if (value == null) {
      return overview.isLoading
          ? const LinearProgressIndicator(minHeight: 2)
          : const SizedBox.shrink();
    }
    final followEnabled = ref.watch(
      featureEnabledProvider(FeatureFlag.artistFollow),
    );
    final unread = followEnabled
        ? ref
                  .watch(unreadReleasesProvider)
                  .valueOrNull
                  ?.countFor(widget.artist) ??
              0
        : 0;
    if (unread > 0 && !_markedSeen) {
      _markedSeen = true;
      // Opening the page marks this artist's releases as seen (badge stays
      // until the next visit).
      unawaited(
        ref.read(artistApiProvider).markSeen(widget.artist).catchError((_) {}),
      );
    }
    final following = _following ?? value.following;
    final showConcerts = ref.watch(
      featureEnabledProvider(FeatureFlag.artistConcerts),
    );
    final showSetlists = ref.watch(
      featureEnabledProvider(FeatureFlag.artistSetlists),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (followEnabled)
              (following ? FilledButton.tonalIcon : OutlinedButton.icon)(
                key: const ValueKey('artist-follow'),
                onPressed: _busy ? null : () => unawaited(_toggleFollow(value)),
                icon: Icon(
                  following
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                ),
                label: Text(
                  following ? 'Вы следите за релизами' : 'Следить за релизами',
                ),
              ),
            if (unread > 0) NewReleasesBadge(count: unread),
          ],
        ),
        if (value.releases.isNotEmpty) ...[
          const FeatureSectionTitle('Новые релизы'),
          for (final release in value.releases.take(6))
            _ReleaseTile(release: release),
        ],
        if (value.clips.isNotEmpty) ...[
          const FeatureSectionTitle('Клипы'),
          for (final clip in value.clips) _ClipTile(clip: clip),
        ],
        if (showConcerts && value.concertsAvailable) ...[
          const FeatureSectionTitle('Концерты'),
          if (value.concerts.isEmpty)
            const FeatureEmpty(
              icon: Icons.event_busy_rounded,
              text: 'Ближайших концертов нет',
            )
          else
            for (final concert in value.concerts)
              _ConcertTile(concert: concert),
        ],
        if (showSetlists &&
            value.setlistsAvailable &&
            value.setlists.isNotEmpty) ...[
          const FeatureSectionTitle('Сет-листы'),
          for (final setlist in value.setlists) _SetlistTile(setlist: setlist),
        ],
      ],
    );
  }
}

class NewReleasesBadge extends StatelessWidget {
  const NewReleasesBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: ResonanceColors.primary,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      count == 1 ? 'Новый релиз' : 'Новых релизов: $count',
      style: const TextStyle(
        color: Colors.black,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

void _openExternal(Uri? url) {
  if (url == null || url.scheme != 'https') return;
  unawaited(launchUrl(url, mode: LaunchMode.externalApplication));
}

class _ReleaseTile extends StatelessWidget {
  const _ReleaseTile({required this.release});

  final ArtistRelease release;

  @override
  Widget build(BuildContext context) => FeatureCard(
    child: Row(
      children: [
        FeatureCover(url: release.artworkUrl),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                release.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                [
                  release.typeLabel,
                  formatShortDate(release.releasedAt),
                ].where((item) => item.isNotEmpty).join(' · '),
                style: const TextStyle(color: ResonanceColors.muted),
              ),
            ],
          ),
        ),
        if (release.url?.scheme == 'https')
          IconButton(
            tooltip: 'Открыть релиз',
            onPressed: () => _openExternal(release.url),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
      ],
    ),
  );
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({required this.clip});

  final ArtistClip clip;

  @override
  Widget build(BuildContext context) => FeatureCard(
    child: Row(
      children: [
        FeatureCover(url: clip.thumbnailUrl),
        const SizedBox(width: 14),
        Expanded(child: Text(clip.title)),
        IconButton(
          tooltip: 'Смотреть на официальной площадке',
          onPressed: clip.url?.scheme == 'https'
              ? () => _openExternal(clip.url)
              : null,
          icon: const Icon(Icons.smart_display_rounded),
        ),
      ],
    ),
  );
}

class _ConcertTile extends StatelessWidget {
  const _ConcertTile({required this.concert});

  final ArtistConcert concert;

  @override
  Widget build(BuildContext context) => FeatureCard(
    child: Row(
      children: [
        const Icon(Icons.event_rounded, color: ResonanceColors.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                concert.place,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                formatShortDate(concert.date),
                style: const TextStyle(color: ResonanceColors.muted),
              ),
            ],
          ),
        ),
        if (concert.url?.scheme == 'https')
          TextButton(
            onPressed: () => _openExternal(concert.url),
            child: const Text('Билеты'),
          ),
      ],
    ),
  );
}

/// Finds catalog matches for set-list songs using the connected providers.
Future<List<UnifiedTrack>> resolveSetlist(
  WidgetRef ref,
  ConcertSetlist setlist,
) async {
  final registry = ref.read(providerRegistryProvider);
  final catalogs = [
    for (final provider in const [
      MusicProvider.soundcloud,
      MusicProvider.yandex,
      MusicProvider.spotify,
      MusicProvider.vk,
    ])
      ?registry.catalogFor(provider),
  ];
  if (catalogs.isEmpty) return const [];
  final results = await Future.wait([
    for (final song in setlist.songs.where((song) => !song.tape))
      () async {
        for (final catalog in catalogs) {
          try {
            final found = await catalog
                .searchTracks(song.query, limit: 1)
                .timeout(const Duration(seconds: 10));
            if (found.isNotEmpty) return found.first;
          } on Object {
            // Try the next provider.
          }
        }
        return null;
      }(),
  ]);
  return results.whereType<UnifiedTrack>().toList();
}

class _SetlistTile extends ConsumerStatefulWidget {
  const _SetlistTile({required this.setlist});

  final ConcertSetlist setlist;

  @override
  ConsumerState<_SetlistTile> createState() => _SetlistTileState();
}

class _SetlistTileState extends ConsumerState<_SetlistTile> {
  bool _loading = false;

  Future<void> _play() async {
    setState(() => _loading = true);
    try {
      final tracks = await resolveSetlist(ref, widget.setlist);
      final count = await playTrackList(ref, tracks);
      if (mounted) {
        showFeatureSnack(
          context,
          count == 0
              ? 'Не нашли песни сет-листа в подключённых каталогах'
              : 'Сет-лист: $count из ${widget.setlist.songs.length} песен',
        );
      }
    } on Object catch (error) {
      if (mounted) showFeatureSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setlist = widget.setlist;
    return FeatureCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(setlist.title.isEmpty ? 'Сет-лист' : setlist.title),
          subtitle: Text(
            [?setlist.tour, '${setlist.songs.length} песен'].join(' · '),
            style: const TextStyle(color: ResonanceColors.muted),
          ),
          trailing: TextButton.icon(
            onPressed: _loading || setlist.songs.isEmpty
                ? null
                : () => unawaited(_play()),
            icon: const Icon(Icons.queue_music_rounded, size: 18),
            label: const Text('Послушать сет-лист'),
          ),
          children: [
            for (final (index, song) in setlist.songs.indexed)
              ListTile(
                dense: true,
                leading: Text('${index + 1}'),
                title: Text(song.title),
                subtitle: song.cover == null
                    ? null
                    : Text('кавер: ${song.cover}'),
              ),
          ],
        ),
      ),
    );
  }
}
