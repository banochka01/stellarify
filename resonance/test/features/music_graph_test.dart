import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/music_graph/music_graph.dart';

void main() {
  const builder = MusicGraphBuilder();

  test('merges the same recording from several providers', () {
    final graph = builder.build([
      _track(
        'yandex:1',
        provider: MusicProvider.yandex,
        externalId: '1',
        duration: const Duration(minutes: 3),
      ),
      _track(
        'spotify:2',
        provider: MusicProvider.spotify,
        externalId: '2',
        duration: const Duration(minutes: 3, seconds: 3),
      ),
    ]);

    expect(graph.nodes, hasLength(1));
    expect(graph.duplicateCount, 1);
    expect(
      graph.nodes.single.track.sources.map((source) => source.provider),
      containsAll([MusicProvider.yandex, MusicProvider.spotify]),
    );
    expect(graph.canonicalFor(_track('spotify:2')).id, 'spotify:2');
  });

  test('keeps materially different durations and named versions separate', () {
    final graph = builder.build([
      _track('studio', duration: const Duration(minutes: 3)),
      _track('extended', duration: const Duration(minutes: 5)),
      _track(
        'live',
        title: 'Signal (Live)',
        normalizedTitle: 'signal live',
        duration: const Duration(minutes: 3),
      ),
    ]);

    expect(graph.nodes, hasLength(3));
    expect(graph.duplicateCount, 0);
  });

  test('connects neighboring recordings by artist and album', () {
    final graph = builder.build([
      _track('one', title: 'One', normalizedTitle: 'one', album: 'Night'),
      _track('two', title: 'Two', normalizedTitle: 'two', album: 'Night'),
      _track('three', title: 'Three', normalizedTitle: 'three', album: 'Day'),
    ]);

    expect(
      graph.edges.where(
        (edge) => edge.relation == MusicGraphRelation.sameArtist,
      ),
      hasLength(2),
    );
    expect(
      graph.edges.where(
        (edge) => edge.relation == MusicGraphRelation.sameAlbum,
      ),
      hasLength(1),
    );
  });

  test('canonical search results preserve the first provider ranking', () {
    final results = builder.canonicalize([
      _track('first', title: 'Zulu', normalizedTitle: 'zulu'),
      _track('second', title: 'Alpha', normalizedTitle: 'alpha'),
      _track(
        'duplicate-first',
        title: 'Zulu',
        normalizedTitle: 'zulu',
        provider: MusicProvider.spotify,
      ),
    ]);

    expect(results.map((track) => track.title), ['Zulu', 'Alpha']);
    expect(results.first.sources, hasLength(2));
  });
}

UnifiedTrack _track(
  String id, {
  String title = 'Signal',
  String normalizedTitle = 'signal',
  String album = 'Night',
  MusicProvider provider = MusicProvider.soundcloud,
  String? externalId,
  Duration? duration,
}) => UnifiedTrack(
  id: id,
  title: title,
  normalizedTitle: normalizedTitle,
  artist: 'Resonance',
  normalizedArtist: 'resonance',
  album: album,
  duration: duration,
  preferredProvider: provider,
  sources: [
    TrackSource(
      provider: provider,
      externalId: externalId ?? id,
      externalUrl: Uri.parse('https://example.com/$id'),
    ),
  ],
);
