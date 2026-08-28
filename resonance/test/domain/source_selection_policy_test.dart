import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/services/source_selection_policy.dart';

void main() {
  final sources = [
    _source(MusicProvider.youtube),
    _source(MusicProvider.yandex),
    _source(MusicProvider.soundcloud),
  ];

  test('orders preferred, last successful, then configurable fallback', () {
    final track = _track(sources, preferred: MusicProvider.soundcloud);
    final policy = SourceSelectionPolicy();

    final ordered = policy.orderedSources(
      track,
      lastSuccessfulProvider: MusicProvider.youtube,
    );

    expect(ordered.map((source) => source.provider), [
      MusicProvider.soundcloud,
      MusicProvider.youtube,
      MusicProvider.yandex,
    ]);
  });

  test('omits disabled providers', () {
    final policy = SourceSelectionPolicy();
    final ordered = policy.orderedSources(
      _track(sources),
      disabledProviders: {MusicProvider.yandex},
    );

    expect(ordered.map((source) => source.provider), [
      MusicProvider.soundcloud,
      MusicProvider.youtube,
    ]);
  });
}

TrackSource _source(MusicProvider provider) => TrackSource(
  provider: provider,
  externalId: provider.name,
  externalUrl: Uri.parse('https://example.com/${provider.name}'),
);

UnifiedTrack _track(List<TrackSource> sources, {MusicProvider? preferred}) =>
    UnifiedTrack(
      id: 'track',
      title: 'Track',
      normalizedTitle: 'track',
      artist: 'Artist',
      normalizedArtist: 'artist',
      sources: sources,
      preferredProvider: preferred,
    );
