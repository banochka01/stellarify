import 'package:resonance/core/playback/demo_audio_source_resolver.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';

final demoTrack = UnifiedTrack(
  id: 'resonance-stage-1-tone',
  title: 'Midnight Signal',
  normalizedTitle: 'midnight signal',
  artist: 'Resonance Lab',
  normalizedArtist: 'resonance lab',
  album: 'Local Session',
  duration: const Duration(seconds: 8),
  preferredProvider: MusicProvider.soundcloud,
  sources: [
    TrackSource(
      provider: MusicProvider.soundcloud,
      externalId: DemoAudioSourceResolver.demoExternalId,
      externalUrl: Uri.parse('https://soundcloud.com/resonance-local/stage-1'),
      metadata: const {
        'assetPath': 'asset:///assets/audio/resonance_test.wav',
        'demoOnly': true,
      },
    ),
  ],
);
