import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_session.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('stores normalized track and sources without stream URL', () async {
    final track = _track('one');

    await database.upsertUnifiedTrack(track);
    final restored = await database.getUnifiedTrack(track.id);

    expect(restored, track);
    final columns = await database
        .customSelect('PRAGMA table_info(stored_tracks)')
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      isNot(contains('stream_url')),
    );
  });

  test('restores playback queue, index, and volume', () async {
    final session = PlaybackSession(
      queue: [_track('one'), _track('two')],
      currentIndex: 1,
      volume: 42,
    );

    await database.replacePlaybackQueue(session);
    final restored = await database.loadPlaybackQueue();

    expect(restored, session);
  });

  test('persists favorites and removes them again', () async {
    final track = _track('favorite');

    await database.setFavorite(track, true);

    expect(await database.isFavorite(track.id), isTrue);
    expect(await database.loadFavoriteTracks(), [track]);

    await database.setFavorite(track, false);

    expect(await database.isFavorite(track.id), isFalse);
    expect(await database.loadFavoriteTracks(), isEmpty);
  });

  test(
    'creates playlists and preserves track order without duplicates',
    () async {
      await database.createLocalPlaylist('playlist-1', 'Ночной вайб');
      await database.addTrackToLocalPlaylist('playlist-1', _track('one'));
      await database.addTrackToLocalPlaylist('playlist-1', _track('two'));
      await database.addTrackToLocalPlaylist('playlist-1', _track('one'));

      final summaries = await database.loadLocalPlaylistSummaries();
      final tracks = await database.loadLocalPlaylistTracks('playlist-1');

      expect(summaries, hasLength(1));
      expect(summaries.single.name, 'Ночной вайб');
      expect(summaries.single.trackCount, 2);
      expect(tracks.map((track) => track.id), ['one', 'two']);
    },
  );
}

UnifiedTrack _track(String id) => UnifiedTrack(
  id: id,
  title: 'Track $id',
  normalizedTitle: 'track $id',
  artist: 'Artist',
  normalizedArtist: 'artist',
  duration: const Duration(minutes: 3),
  preferredProvider: MusicProvider.soundcloud,
  sources: [
    TrackSource(
      provider: MusicProvider.soundcloud,
      externalId: 'external-$id',
      externalUrl: Uri.parse('https://soundcloud.com/artist/$id'),
      metadata: const {'genre': 'test'},
    ),
  ],
);
