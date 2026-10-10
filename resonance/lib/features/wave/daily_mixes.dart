import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/wave/wave_blocks.dart';

/// One of the "Ваш день" mixes: Утро, Фокус, Вечер, Открытия.
final class DailyMix {
  const DailyMix({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.tracks,
  });

  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final List<UnifiedTrack> tracks;
}

final class DailyMixes {
  const DailyMixes({required this.mixes, this.nextRefreshAt});

  final List<DailyMix> mixes;
  final DateTime? nextRefreshAt;
}

/// Mixes refresh each morning at 06:00 local time; the server caches them for
/// the whole day, so this provider can be re-read freely.
final dailyMixesProvider = FutureProvider<DailyMixes>((ref) async {
  final library = await ref.watch(libraryControllerProvider.future);
  final blocks = ref.watch(waveBlocksProvider.notifier);
  ref.watch(waveBlocksProvider);
  final database = ref.read(appDatabaseProvider);
  final now = DateTime.now();
  final history = await database.loadListeningHistory(
    since: now.subtract(const Duration(days: 60)),
    limit: 3000,
  );
  final recentCut = now.subtract(const Duration(days: 30));
  final recent = {
    for (final entry in history)
      if (entry.playedAt.isAfter(recentCut)) waveTrackKey(entry.track),
  };
  final artistCounts = <String, int>{};
  for (final track in library.favorites) {
    artistCounts.update(track.artist, (value) => value + 3, ifAbsent: () => 3);
  }
  for (final entry in history) {
    if (entry.listened >= const Duration(seconds: 30)) {
      artistCounts.update(
        entry.track.artist,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
  }
  final artists = artistCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final forgotten = [
    for (final track in library.favorites)
      if (!recent.contains(waveTrackKey(track)))
        {'title': track.title, 'artist': track.artist},
  ];
  final response = await ref
      .read(resonanceHttpClientProvider)
      .dio
      .postUri<Map<String, dynamic>>(
        BackendEndpoint.requireCurrent().resolve('/api/v1/wave/daily-mixes'),
        data: {
          'favoriteArtists': artists
              .take(30)
              .map((entry) => entry.key)
              .toList(),
          'forgottenTracks': forgotten.take(30).toList(),
          'blockedArtists': blocks.blockedArtists,
          'blockedTracks': blocks.blockedTracks,
          'enabledProviders': ['soundcloud', 'yandex'],
          'tzOffsetMinutes': now.timeZoneOffset.inMinutes,
        },
        options: await providerTokenOptions(
          ref.read(secureTokenRepositoryProvider),
        ),
      );
  return parseDailyMixes(response.data);
});

DailyMixes parseDailyMixes(Map<String, dynamic>? json) {
  final raw = json?['mixes'];
  if (raw is! List) return const DailyMixes(mixes: []);
  final mixes = <DailyMix>[];
  for (final item in raw) {
    final map = Map<String, dynamic>.from(item as Map);
    final tracks = [
      for (final track in map['tracks'] as List? ?? const [])
        ?unifiedTrackFromWaveItem(Map<String, dynamic>.from(track as Map)),
    ];
    if (tracks.isEmpty) continue;
    mixes.add(
      DailyMix(
        id: map['id'] as String? ?? '',
        kind: map['kind'] as String? ?? '',
        title: map['title'] as String? ?? 'Микс',
        subtitle: map['subtitle'] as String? ?? '',
        tracks: tracks,
      ),
    );
  }
  return DailyMixes(
    mixes: mixes,
    nextRefreshAt: DateTime.tryParse(json?['nextRefreshAt'] as String? ?? ''),
  );
}

/// Maps a server `WaveItem` to a playable track; unknown providers are dropped.
UnifiedTrack? unifiedTrackFromWaveItem(Map<String, dynamic> item) {
  final providerName = item['provider'];
  final id = item['id'];
  final title = item['title'];
  final artist = item['artist'];
  final url = Uri.tryParse(item['externalUrl'] as String? ?? '');
  if (providerName is! String ||
      id is! String ||
      title is! String ||
      artist is! String ||
      url == null) {
    return null;
  }
  final provider = MusicProvider.values
      .where((value) => value.name == providerName)
      .firstOrNull;
  if (provider == null) return null;
  final artwork = Uri.tryParse(item['artworkUrl'] as String? ?? '');
  return UnifiedTrack(
    id: '${provider.name}:$id',
    title: title,
    normalizedTitle: title.trim().toLowerCase(),
    artist: artist,
    normalizedArtist: artist.trim().toLowerCase(),
    album: item['album'] as String?,
    duration: item['durationMs'] is num
        ? Duration(milliseconds: (item['durationMs'] as num).toInt())
        : null,
    artworkUrl: artwork?.isScheme('https') == true ? artwork : null,
    preferredProvider: provider,
    sources: [
      TrackSource(
        provider: provider,
        externalId: id,
        externalUrl: url,
        metadata: {if (item['reason'] is String) 'waveReason': item['reason']},
      ),
    ],
  );
}

Future<Options?> providerTokenOptions(SecureTokenRepository tokens) async {
  final headers = <String, String>{};
  for (final provider in MusicProvider.values) {
    final token = await tokens.read(provider);
    if (token?.isNotEmpty == true) headers['X-${provider.name}-Token'] = token!;
  }
  return headers.isEmpty ? null : Options(headers: headers);
}
