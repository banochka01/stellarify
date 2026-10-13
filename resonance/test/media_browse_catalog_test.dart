import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/core/playback/media_browse_catalog.dart';
import 'package:resonance/domain/entities/unified_track.dart';

UnifiedTrack _track(String id) => UnifiedTrack(
  id: id,
  title: 'Title $id',
  normalizedTitle: 'title $id',
  artist: 'Artist',
  normalizedArtist: 'artist',
);

final class _FakeSource implements MediaBrowseSource {
  final recent = [_track('a'), _track('b')];
  final playlist = [_track('p1'), _track('p2'), _track('p3')];
  bool waveStarted = false;
  List<UnifiedTrack>? played;
  int? playedIndex;

  @override
  Future<List<UnifiedTrack>> recentTracks() async => recent;

  @override
  Future<List<LocalPlaylistSummary>> playlists() async => [
    LocalPlaylistSummary(
      id: 'pl',
      name: 'Дорога',
      trackCount: 3,
      updatedAt: DateTime(2026),
      createdAt: DateTime(2026),
    ),
  ];

  @override
  Future<List<UnifiedTrack>> playlistTracks(String playlistId) async =>
      playlistId == 'pl' ? playlist : const [];

  @override
  Future<List<UnifiedTrack>> favoriteTracks() async => [_track('f')];

  @override
  Future<void> startWave() async => waveStarted = true;

  @override
  Future<void> playTracks(List<UnifiedTrack> tracks, int startIndex) async {
    played = tracks;
    playedIndex = startIndex;
  }
}

void main() {
  test('root exposes recent, playlists, wave and mixes', () async {
    final catalog = MediaBrowseCatalog(_FakeSource());
    final root = await catalog.children(AudioService.browsableRootId);
    expect(root.map((item) => item.title), [
      'Недавнее',
      'Плейлисты',
      'Волна',
      'Миксы',
    ]);
    expect(root[2].playable, isTrue);
  });

  test('playlist tracks are browsable and play from their position', () async {
    final source = _FakeSource();
    final catalog = MediaBrowseCatalog(source);
    final playlists = await catalog.children(MediaBrowseCatalog.playlistsId);
    expect(playlists.single.title, 'Дорога');
    final tracks = await catalog.children(playlists.single.id);
    expect(tracks, hasLength(3));
    await catalog.playFromMediaId(tracks[1].id);
    expect(source.played?.map((t) => t.id), ['p1', 'p2', 'p3']);
    expect(source.playedIndex, 1);
  });

  test('wave and mixes start playback', () async {
    final source = _FakeSource();
    final catalog = MediaBrowseCatalog(source);
    await catalog.playFromMediaId(MediaBrowseCatalog.waveId);
    expect(source.waveStarted, isTrue);
    await catalog.playFromMediaId(MediaBrowseCatalog.favoritesMixId);
    expect(source.played?.single.id, 'f');
  });

  test('unknown ids are ignored', () async {
    final source = _FakeSource();
    final catalog = MediaBrowseCatalog(source);
    expect(await catalog.children('nope'), isEmpty);
    await catalog.playFromMediaId('resonance:recent|track:missing');
    expect(source.played, isNull);
  });
}
