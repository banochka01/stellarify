import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/platform/feature_api.dart';

/// Wire contract for /api/v1/artists/* and /api/v1/setlists
/// (docs/API-5.0.md §3–4).
abstract final class ArtistPaths {
  static const overview = '/api/v1/artists/overview';
  static const follows = '/api/v1/artists/follows';
  static const unread = '/api/v1/artists/releases/unread';
  static const seen = '/api/v1/artists/releases/seen';
  static const setlists = '/api/v1/setlists';
}

final class ArtistRelease {
  const ArtistRelease({
    required this.id,
    required this.title,
    this.type = 'album',
    this.releasedAt,
    this.artworkUrl,
    this.url,
    this.artist,
  });

  factory ArtistRelease.fromJson(Map<String, dynamic> json) => ArtistRelease(
    id: jsonString(json['id']),
    title: jsonString(json['title'] ?? json['name']),
    type: jsonString(json['type'] ?? json['albumType'], 'album'),
    releasedAt: jsonDate(json['releaseDate'] ?? json['releasedAt']),
    artworkUrl: jsonOptString(json['artworkUrl'] ?? json['imageUrl']),
    url: Uri.tryParse(jsonString(json['url'] ?? json['externalUrl'])),
    artist: jsonOptString(json['followedArtist'] ?? json['artist']),
  );

  final String id;
  final String title;
  final String type;
  final DateTime? releasedAt;
  final String? artworkUrl;
  final Uri? url;
  final String? artist;

  String get typeLabel => switch (type) {
    'single' => 'Сингл',
    'ep' => 'EP',
    'compilation' => 'Сборник',
    _ => 'Альбом',
  };
}

final class ArtistClip {
  const ArtistClip({required this.title, this.url, this.thumbnailUrl});

  factory ArtistClip.fromJson(Map<String, dynamic> json) => ArtistClip(
    title: jsonString(json['title']),
    url: Uri.tryParse(jsonString(json['url'] ?? json['pageUrl'])),
    thumbnailUrl: jsonOptString(json['thumbnailUrl'] ?? json['thumbnail']),
  );

  final String title;
  final Uri? url;
  final String? thumbnailUrl;
}

final class ArtistConcert {
  const ArtistConcert({
    required this.id,
    this.date,
    this.venue = '',
    this.city = '',
    this.country = '',
    this.url,
  });

  factory ArtistConcert.fromJson(Map<String, dynamic> json) => ArtistConcert(
    id: jsonString(json['id']),
    date: jsonDate(json['date']),
    venue: jsonString(json['venue']),
    city: jsonString(json['city']),
    country: jsonString(json['country']),
    url: Uri.tryParse(jsonString(json['url'])),
  );

  final String id;
  final DateTime? date;
  final String venue;
  final String city;
  final String country;
  final Uri? url;

  String get place => [city, venue].where((item) => item.isNotEmpty).join(', ');
}

final class SetlistSong {
  const SetlistSong({
    required this.title,
    required this.query,
    this.cover,
    this.tape = false,
  });

  factory SetlistSong.fromJson(Map<String, dynamic> json) => SetlistSong(
    title: jsonString(json['title']),
    query: jsonString(json['query'], jsonString(json['title'])),
    cover: jsonOptString(json['cover']),
    tape: jsonBool(json['tape']),
  );

  final String title;

  /// Ready search query for the catalog (covers include the original artist).
  final String query;
  final String? cover;
  final bool tape;
}

final class ConcertSetlist {
  const ConcertSetlist({
    required this.id,
    required this.songs,
    this.eventDate,
    this.venue = '',
    this.city = '',
    this.tour,
  });

  factory ConcertSetlist.fromJson(Map<String, dynamic> json) => ConcertSetlist(
    id: jsonString(json['id']),
    eventDate: jsonDate(json['eventDate']),
    venue: jsonString(json['venue']),
    city: jsonString(json['city']),
    tour: jsonOptString(json['tour']),
    songs: jsonList(json['tracks']).map(SetlistSong.fromJson).toList(),
  );

  final String id;
  final DateTime? eventDate;
  final String venue;
  final String city;
  final String? tour;
  final List<SetlistSong> songs;

  String get title => [
    city,
    venue,
    formatShortDate(eventDate),
  ].where((item) => item.isNotEmpty).join(' · ');
}

final class ArtistOverview {
  const ArtistOverview({
    required this.name,
    this.following = false,
    this.releasesAvailable = false,
    this.releases = const [],
    this.clips = const [],
    this.concertsAvailable = false,
    this.concerts = const [],
    this.setlistsAvailable = false,
    this.setlists = const [],
    this.topTracks = const [],
  });

  factory ArtistOverview.fromJson(Map<String, dynamic> json) {
    final releases = jsonMap(json['releases']);
    final concerts = jsonMap(json['concerts']);
    final setlists = jsonMap(json['setlists']);
    return ArtistOverview(
      name: jsonString(
        json['artist'] is Map
            ? jsonMap(json['artist'])['name']
            : json['artist'],
      ),
      following: jsonBool(json['following']),
      releasesAvailable: jsonBool(releases['available']),
      releases: jsonList(
        releases['items'],
      ).map(ArtistRelease.fromJson).toList(),
      clips: jsonList(json['clips']).map(ArtistClip.fromJson).toList(),
      concertsAvailable: jsonBool(concerts['available']),
      concerts: jsonList(
        concerts['items'],
      ).map(ArtistConcert.fromJson).toList(),
      setlistsAvailable: jsonBool(setlists['available']),
      setlists: jsonList(
        setlists['setlists'],
      ).map(ConcertSetlist.fromJson).toList(),
      topTracks: jsonTracks(json['topTracks']),
    );
  }

  final String name;
  final bool following;
  final bool releasesAvailable;
  final List<ArtistRelease> releases;
  final List<ArtistClip> clips;
  final bool concertsAvailable;
  final List<ArtistConcert> concerts;
  final bool setlistsAvailable;
  final List<ConcertSetlist> setlists;
  final List<UnifiedTrack> topTracks;
}

final class UnreadReleases {
  const UnreadReleases({this.count = 0, this.releases = const []});

  factory UnreadReleases.fromJson(Map<String, dynamic> json) => UnreadReleases(
    count: jsonInt(json['count']),
    releases: jsonList(json['releases']).map(ArtistRelease.fromJson).toList(),
  );

  final int count;
  final List<ArtistRelease> releases;

  int countFor(String artist) {
    final key = artist.trim().toLowerCase();
    return releases
        .where((release) => release.artist?.trim().toLowerCase() == key)
        .length;
  }
}

final class ArtistApi {
  const ArtistApi(this._transport);

  final FeatureTransport _transport;

  Future<ArtistOverview> overview(String name) async => ArtistOverview.fromJson(
    await _transport.request(
      'GET',
      ArtistPaths.overview,
      query: {'name': name, 'provider': 'soundcloud'},
      providerTokens: true,
    ),
  );

  Future<void> setFollowing(String artist, {required bool following}) =>
      following
      ? _transport.request('PUT', ArtistPaths.follows, body: {'artist': artist})
      : _transport.request(
          'DELETE',
          ArtistPaths.follows,
          query: {'artist': artist},
        );

  Future<UnreadReleases> unread() async => UnreadReleases.fromJson(
    await _transport.request('GET', ArtistPaths.unread),
  );

  Future<void> markSeen(String artist) =>
      _transport.request('POST', ArtistPaths.seen, body: {'artist': artist});
}

final artistApiProvider = Provider<ArtistApi>(
  (ref) => ArtistApi(ref.watch(featureTransportProvider)),
);

final artistOverviewProvider = FutureProvider.autoDispose
    .family<ArtistOverview, String>(
      (ref, name) => ref.watch(artistApiProvider).overview(name),
    );

/// Unread releases of followed artists (for badges); empty on any error.
final unreadReleasesProvider = FutureProvider.autoDispose<UnreadReleases>((
  ref,
) async {
  try {
    return await ref.watch(artistApiProvider).unread();
  } on Object {
    return const UnreadReleases();
  }
});
