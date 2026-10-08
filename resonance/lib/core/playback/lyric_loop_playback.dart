import 'package:resonance/domain/entities/playback_state.dart';

/// То, что нужно повтору строки от плеера; `PlaybackService` подходит как есть.
abstract interface class LyricLoopPlayback {
  ResonancePlaybackState get state;
  Stream<ResonancePlaybackState> get states;
  Future<void> seek(Duration position);
}
