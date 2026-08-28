import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';

abstract interface class AudioSourceResolver {
  MusicProvider get provider;

  Future<ResolvedAudioSource> resolve(
    TrackSource source, {
    AudioQuality quality = AudioQuality.high,
  });
}
