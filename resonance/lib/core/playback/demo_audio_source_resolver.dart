import 'package:resonance/core/errors/app_exception.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/providers/audio_source_resolver.dart';

final class DemoAudioSourceResolver implements AudioSourceResolver {
  static const demoExternalId = 'stage-1-test-tone';

  @override
  MusicProvider get provider => MusicProvider.soundcloud;

  @override
  Future<ResolvedAudioSource> resolve(
    TrackSource source, {
    AudioQuality quality = AudioQuality.high,
  }) async {
    if (source.externalId != demoExternalId ||
        source.metadata['assetPath'] is! String) {
      throw const AudioResolutionException(
        'Stage 1 resolver can only open the bundled test tone.',
      );
    }
    return ResolvedAudioSource(
      streamUrl: Uri.parse(source.metadata['assetPath']! as String),
      protocol: StreamProtocol.progressive,
      codec: 'pcm_s16le',
      bitrate: 705600,
    );
  }
}
