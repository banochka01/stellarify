import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/music_graph/music_graph.dart';
import 'package:resonance/providers/common/provider_registry.dart';

/// Metadata-only artist profile served by `/api/v1/artists`. Tracks here are
/// catalog references; playback always goes through [ArtistTrackResolver].
final class ArtistProfile {
  const ArtistProfile({
    required this.name,
    this.pictureUrl,
    this.fans,
    this.albumCount,
    this.topTracks = const [],
    this.albums = const [],
    this.related = const [],
  });

  factory ArtistProfile.fromJson(Map<String, dynamic> json) {
    final artist = Map<String, dynamic>.from(json['artist'] as Map);
    return ArtistProfile(
      name: artist['name'] as String,
      pictureUrl: _uri(artist['pictureUrl']),
      fans: (artist['fans'] as num?)?.toInt(),
      albumCount: (artist['albumCount'] as num?)?.toInt(),
      topTracks: _list(json['topTracks'], ArtistTrackInfo.fromJson),
      albums: _list(json['albums'], ArtistAlbumInfo.fromJson),
      related: _list(json['related'], ArtistSummary.fromJson),
    );
  }

  final String name;
  final Uri? pictureUrl;
  final int? fans;
  final int? albumCount;
  final List<ArtistTrackInfo> topTracks;
  final List<ArtistAlbumInfo> albums;
  final List<ArtistSummary> related;
}

final class ArtistTrackInfo {
  const ArtistTrackInfo({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.artworkUrl,
    this.duration,
  });

  factory ArtistTrackInfo.fromJson(Map<String, dynamic> json) =>
      ArtistTrackInfo(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String? ?? '',
        album: json['album'] as String?,
        artworkUrl: _uri(json['artworkUrl']),
        duration: json['durationMs'] is num
            ? Duration(milliseconds: (json['durationMs'] as num).toInt())
            : null,
      );

  final String id;
  final String title;
  final String artist;
  final String? album;
  final Uri? artworkUrl;
  final Duration? duration;
}

final class ArtistAlbumInfo {
  const ArtistAlbumInfo({
    required this.id,
    required this.title,
    this.artworkUrl,
    this.releaseDate,
    this.type = 'album',
  });

  factory ArtistAlbumInfo.fromJson(Map<String, dynamic> json) =>
      ArtistAlbumInfo(
        id: json['id'] as String,
        title: json['title'] as String,
        artworkUrl: _uri(json['artworkUrl']),
        releaseDate: DateTime.tryParse(json['releaseDate'] as String? ?? ''),
        type: json['type'] as String? ?? 'album',
      );

  final String id;
  final String title;
  final Uri? artworkUrl;
  final DateTime? releaseDate;
  final String type;

  bool get isSingle => type == 'single' || type == 'ep';
}

final class ArtistSummary {
  const ArtistSummary({required this.name, this.pictureUrl, this.fans});

  factory ArtistSummary.fromJson(Map<String, dynamic> json) => ArtistSummary(
    name: json['name'] as String,
    pictureUrl: _uri(json['pictureUrl']),
    fans: (json['fans'] as num?)?.toInt(),
  );

  final String name;
  final Uri? pictureUrl;
  final int? fans;
}

final class ArtistAlbumDetails {
  const ArtistAlbumDetails({required this.album, required this.tracks});

  factory ArtistAlbumDetails.fromJson(Map<String, dynamic> json) =>
      ArtistAlbumDetails(
        album: ArtistAlbumInfo.fromJson(
          Map<String, dynamic>.from(json['album'] as Map),
        ),
        tracks: _list(json['tracks'], ArtistTrackInfo.fromJson),
      );

  final ArtistAlbumInfo album;
  final List<ArtistTrackInfo> tracks;
}

abstract interface class ArtistCatalog {
  Future<ArtistProfile?> profile(String name);
  Future<ArtistAlbumDetails?> album(String id);
}

final class BackendArtistCatalog implements ArtistCatalog {
  BackendArtistCatalog(this._dio, this._baseUri);

  final Dio _dio;
  final Uri Function() _baseUri;

  @override
  Future<ArtistProfile?> profile(String name) async {
    final json = await _get(
      _baseUri()
          .resolve('/api/v1/artists')
          .replace(queryParameters: {'name': name}),
    );
    return json == null ? null : ArtistProfile.fromJson(json);
  }

  @override
  Future<ArtistAlbumDetails?> album(String id) async {
    final json = await _get(
      _baseUri().resolve('/api/v1/artists/albums/${Uri.encodeComponent(id)}'),
    );
    return json == null ? null : ArtistAlbumDetails.fromJson(json);
  }

  Future<Map<String, dynamic>?> _get(Uri uri) async {
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(uri);
      return response.data;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

/// Whether a Resonance backend is configured; artist data needs one.
final artistBackendAvailableProvider = Provider<bool>((ref) {
  return BackendEndpoint.displayValue.isNotEmpty;
});

final artistCatalogProvider = Provider<ArtistCatalog>((ref) {
  return BackendArtistCatalog(
    ref.watch(resonanceHttpClientProvider).dio,
    BackendEndpoint.requireCurrent,
  );
});

/// Remote profile, or `null` when the backend has no data for this name or
/// is unreachable. The artist page still renders from playable sources then.
final artistProfileProvider = FutureProvider.autoDispose
    .family<ArtistProfile?, String>((ref, name) async {
      if (!ref.watch(artistBackendAvailableProvider)) return null;
      try {
        return await ref.watch(artistCatalogProvider).profile(name);
      } on Object {
        return null;
      }
    });

final artistAlbumProvider = FutureProvider.autoDispose
    .family<ArtistAlbumDetails?, String>((ref, id) {
      return ref.watch(artistCatalogProvider).album(id);
    });

/// Playable tracks by this artist: library first, then live provider search.
final artistPlayableTracksProvider = FutureProvider.autoDispose
    .family<List<UnifiedTrack>, String>((ref, name) async {
      final library = ref.watch(libraryControllerProvider).valueOrNull;
      final owned = libraryTracksByArtist(library, name);
      if (!ref.watch(artistBackendAvailableProvider)) return owned;
      final found = await ArtistTrackResolver(
        ref.watch(providerRegistryProvider),
      ).searchArtist(name);
      return const MusicGraphBuilder().canonicalize([...owned, ...found]);
    });

List<UnifiedTrack> libraryTracksByArtist(LibraryState? library, String name) {
  if (library == null) return const [];
  final wanted = normalizeArtistKey(name);
  final tracks = <String, UnifiedTrack>{};
  for (final track in [
    ...library.favorites,
    ...library.tracks,
    ...library.graphTracks,
  ]) {
    if (artistCredits(
      track.artist,
    ).any((a) => normalizeArtistKey(a) == wanted)) {
      tracks.putIfAbsent(track.id, () => track);
    }
  }
  return tracks.values.toList(growable: false);
}

/// Maps catalog references to tracks the user's providers can actually play.
final class ArtistTrackResolver {
  ArtistTrackResolver(this._registry);

  static const searchProviders = [
    MusicProvider.yandex,
    MusicProvider.soundcloud,
    MusicProvider.spotify,
    MusicProvider.vk,
  ];

  final ProviderRegistry _registry;

  Future<List<UnifiedTrack>> searchArtist(String name, {int limit = 30}) async {
    final wanted = normalizeArtistKey(name);
    final results = await _search(name, limit);
    return results
        .where(
          (track) => artistCredits(
            track.artist,
          ).any((credit) => normalizeArtistKey(credit) == wanted),
        )
        .toList(growable: false);
  }

  /// Finds the best playable match for [info], first among [known] tracks and
  /// then through a targeted provider search.
  Future<UnifiedTrack?> resolve(
    ArtistTrackInfo info, {
    Iterable<UnifiedTrack> known = const [],
  }) async {
    final local = bestTrackMatch(info.title, info.artist, known);
    if (local != null) return local;
    final results = await _search('${info.artist} ${info.title}', 8);
    return bestTrackMatch(info.title, info.artist, results);
  }

  Future<List<UnifiedTrack>> resolveAll(
    Iterable<ArtistTrackInfo> infos, {
    Iterable<UnifiedTrack> known = const [],
  }) async {
    final list = infos.toList(growable: false);
    final resolved = List<UnifiedTrack?>.filled(list.length, null);
    // A small window keeps a 15-track "play all" responsive without flooding
    // every provider with parallel searches.
    for (var start = 0; start < list.length; start += 4) {
      final end = (start + 4).clamp(0, list.length);
      final batch = await Future.wait([
        for (var i = start; i < end; i++)
          resolve(list[i], known: known).onError((_, _) => null),
      ]);
      for (var i = start; i < end; i++) {
        resolved[i] = batch[i - start];
      }
    }
    final unique = <String, UnifiedTrack>{};
    for (final track in resolved.nonNulls) {
      unique.putIfAbsent(track.id, () => track);
    }
    return unique.values.toList(growable: false);
  }

  Future<List<UnifiedTrack>> _search(String query, int limit) async {
    final searches = <Future<List<UnifiedTrack>>>[
      for (final provider in searchProviders)
        if (_registry.catalogFor(provider) case final catalog?)
          catalog
              .searchTracks(query, limit: limit)
              .onError((_, _) => const <UnifiedTrack>[]),
    ];
    final batches = await Future.wait(searches);
    return const MusicGraphBuilder().canonicalize(batches.expand((b) => b));
  }
}

UnifiedTrack? bestTrackMatch(
  String title,
  String artist,
  Iterable<UnifiedTrack> candidates,
) {
  final wantedTitle = normalizeTitleKey(title);
  final wantedArtist = normalizeArtistKey(artist);
  UnifiedTrack? best;
  var bestScore = 0;
  for (final track in candidates) {
    final candidateTitle = normalizeTitleKey(track.title);
    if (candidateTitle.isEmpty) continue;
    final artistMatch = artistCredits(
      track.artist,
    ).any((credit) => normalizeArtistKey(credit) == wantedArtist);
    if (!artistMatch) continue;
    final score = candidateTitle == wantedTitle
        ? 3
        : candidateTitle.startsWith(wantedTitle) ||
              wantedTitle.startsWith(candidateTitle)
        ? 2
        : 0;
    if (score > bestScore) {
      best = track;
      bestScore = score;
    }
  }
  return best;
}

final _creditSplit = RegExp(
  r'\s*(?:,|&|\+|/|\bfeat\.?|\bft\.?|\bfeaturing\b|\s[xх×]\s)\s*',
  caseSensitive: false,
);

/// Individual artists credited on a track, main artist first.
List<String> artistCredits(String artist) => artist
    .split(_creditSplit)
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList(growable: false);

/// The artist an artist page should open for a credit like "A feat. B".
String primaryArtist(String artist) {
  final credits = artistCredits(artist);
  return credits.isEmpty ? artist.trim() : credits.first;
}

String normalizeArtistKey(String value) => value
    .toLowerCase()
    .replaceFirst(RegExp(r'^the\s+'), '')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

String normalizeTitleKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'\s*[\(\[][^\)\]]*[\)\]]'), '')
    .replaceAll(RegExp(r'\s+-\s+.*$'), '')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

Uri? _uri(Object? value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value);
  return uri != null && uri.isScheme('https') ? uri : null;
}

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  final items = <T>[];
  for (final item in value) {
    if (item is! Map) continue;
    try {
      items.add(parse(Map<String, dynamic>.from(item)));
    } on Object {
      // Skip a malformed entry rather than failing the whole page.
    }
  }
  return items;
}
