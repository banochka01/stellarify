import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';

part 'playback_state.freezed.dart';

@freezed
abstract class ResonancePlaybackState with _$ResonancePlaybackState {
  const ResonancePlaybackState._();

  const factory ResonancePlaybackState({
    @Default(<UnifiedTrack>[]) List<UnifiedTrack> queue,
    @Default(-1) int currentIndex,
    @Default(false) bool playing,
    @Default(false) bool buffering,
    @Default(Duration.zero) Duration position,
    @Default(Duration.zero) Duration duration,
    @Default(70) double volume,
    @Default(false) bool shuffle,
    @Default(PlaybackRepeatMode.off) PlaybackRepeatMode repeatMode,
    TrackSource? activeTrackSource,
    ResolvedAudioSource? activeAudioSource,
    String? errorMessage,
  }) = _ResonancePlaybackState;

  UnifiedTrack? get currentTrack {
    if (currentIndex < 0 || currentIndex >= queue.length) {
      return null;
    }
    return queue[currentIndex];
  }
}
