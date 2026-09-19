import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/player/track_action.dart';

void main() {
  test(
    'favorite queue keeps playable tracks and skips YouTube-only metadata',
    () {
      final youtubeOnly = _track('youtube', MusicProvider.youtube);
      final spotify = _track('spotify', MusicProvider.spotify);
      final merged = UnifiedTrack(
        id: 'merged',
        title: 'Merged',
        normalizedTitle: 'merged',
        artist: 'Artist',
        normalizedArtist: 'artist',
        preferredProvider: MusicProvider.youtube,
        sources: [
          _source('youtube', MusicProvider.youtube),
          _source('soundcloud', MusicProvider.soundcloud),
        ],
      );

      expect(
        playableQueueTracks([
          youtubeOnly,
          spotify,
          merged,
        ]).map((item) => item.id),
        ['spotify', 'merged'],
      );
    },
  );
}

UnifiedTrack _track(String id, MusicProvider provider) => UnifiedTrack(
  id: id,
  title: id,
  normalizedTitle: id,
  artist: 'Artist',
  normalizedArtist: 'artist',
  preferredProvider: provider,
  sources: [_source(id, provider)],
);

TrackSource _source(String id, MusicProvider provider) => TrackSource(
  provider: provider,
  externalId: id,
  externalUrl: Uri.parse('https://example.com/$id'),
);
