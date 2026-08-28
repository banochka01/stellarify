import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/playback/resolved_source_cache.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';

void main() {
  test('evicts expired stream URLs', () {
    final now = DateTime.utc(2026, 7, 31, 12);
    final source = TrackSource(
      provider: MusicProvider.youtube,
      externalId: 'video',
      externalUrl: Uri.parse('https://youtube.com/watch?v=video'),
    );
    final resolved = ResolvedAudioSource(
      streamUrl: Uri.parse('https://googlevideo.com/audio'),
      protocol: StreamProtocol.dash,
      expiresAt: now.add(const Duration(minutes: 1)),
    );
    final cache = ResolvedSourceCache(now: () => now)..put(source, resolved);

    expect(cache.get(source, now: now), resolved);
    expect(cache.get(source, now: now.add(const Duration(minutes: 2))), isNull);
  });
}
