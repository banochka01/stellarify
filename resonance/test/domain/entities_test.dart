import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';

void main() {
  test('UnifiedTrack round-trips provider sources through JSON', () {
    final track = UnifiedTrack(
      id: 'track-1',
      title: 'Signal',
      normalizedTitle: 'signal',
      artist: 'Resonance',
      normalizedArtist: 'resonance',
      album: 'Foundation',
      duration: const Duration(minutes: 3, seconds: 12),
      artworkUrl: Uri.parse('https://i.ytimg.com/cover.jpg'),
      preferredProvider: MusicProvider.youtube,
      sources: [
        TrackSource(
          provider: MusicProvider.youtube,
          externalId: 'video-id',
          externalUrl: Uri.parse('https://youtube.com/watch?v=video-id'),
          metadata: const {'isrc': 'TEST123'},
        ),
      ],
    );

    final restored = UnifiedTrack.fromJson(track.toJson());

    expect(restored, track);
    expect(restored.duration, const Duration(minutes: 3, seconds: 12));
    expect(restored.sources.single.metadata['isrc'], 'TEST123');
  });

  test(
    'ResolvedAudioSource treats expiration as non-persistent capability',
    () {
      final now = DateTime.utc(2026, 7, 31, 12);
      final source = ResolvedAudioSource(
        streamUrl: Uri.parse('https://media.sndcdn.com/audio.m4a'),
        protocol: StreamProtocol.progressive,
        expiresAt: now.add(const Duration(minutes: 5)),
        headers: const {'Referer': 'https://soundcloud.com/'},
      );

      expect(source.isExpired(now), isFalse);
      expect(source.isExpired(now.add(const Duration(minutes: 6))), isTrue);
      expect(ResolvedAudioSource.fromJson(source.toJson()), source);
    },
  );
}
