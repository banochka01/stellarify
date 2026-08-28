import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:resonance/domain/entities/unified_track.dart';

part 'playback_session.freezed.dart';

@freezed
abstract class PlaybackSession with _$PlaybackSession {
  const factory PlaybackSession({
    @Default(<UnifiedTrack>[]) List<UnifiedTrack> queue,
    @Default(-1) int currentIndex,
    @Default(70) double volume,
  }) = _PlaybackSession;
}
