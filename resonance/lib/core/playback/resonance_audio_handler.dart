import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/playback_state.dart';

final class ResonanceAudioHandler extends audio_service.BaseAudioHandler
    with audio_service.QueueHandler, audio_service.SeekHandler {
  ResonanceAudioHandler(this._service, {this.onLike}) {
    _subscription = _service.states.listen(_publish);
    _publish(_service.state);
  }

  final PlaybackService _service;

  /// Toggles the current track in Favorites ("Нравится" notification action).
  final Future<void> Function()? onLike;

  static const likeActionName = 'like';
  static final _like = audio_service.MediaControl.custom(
    androidIcon: 'drawable/ic_notification_like',
    label: 'Нравится',
    name: likeActionName,
  );
  late final StreamSubscription<ResonancePlaybackState> _subscription;

  void _publish(ResonancePlaybackState state) {
    final track = state.currentTrack;
    mediaItem.add(
      track == null
          ? null
          : audio_service.MediaItem(
              id: track.id,
              title: track.title,
              artist: track.artist,
              album: track.album,
              duration: track.duration,
              artUri: track.artworkUrl,
            ),
    );
    queue.add(
      state.queue
          .map(
            (track) => audio_service.MediaItem(
              id: track.id,
              title: track.title,
              artist: track.artist,
              album: track.album,
              duration: track.duration,
              artUri: track.artworkUrl,
            ),
          )
          .toList(growable: false),
    );
    playbackState.add(
      audio_service.PlaybackState(
        controls: [
          audio_service.MediaControl.skipToPrevious,
          if (state.playing)
            audio_service.MediaControl.pause
          else
            audio_service.MediaControl.play,
          audio_service.MediaControl.skipToNext,
          if (onLike != null && track != null) _like,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {
          audio_service.MediaAction.seek,
          audio_service.MediaAction.seekForward,
          audio_service.MediaAction.seekBackward,
        },
        processingState: track == null
            ? audio_service.AudioProcessingState.idle
            : state.buffering
            ? audio_service.AudioProcessingState.buffering
            : audio_service.AudioProcessingState.ready,
        playing: state.playing,
        updatePosition: state.position,
        bufferedPosition: state.position,
        queueIndex: state.currentIndex < 0 ? null : state.currentIndex,
      ),
    );
  }

  @override
  Future<void> play() => _service.play();

  @override
  Future<void> pause() => _service.pause();

  @override
  Future<void> seek(Duration position) => _service.seek(position);

  @override
  Future<void> skipToNext() => _service.next();

  @override
  Future<void> skipToPrevious() => _service.previous();

  @override
  Future<void> stop() async {
    await _service.pause();
    await super.stop();
  }

  @override
  Future<void> fastForward() =>
      _service.seek(_service.state.position + const Duration(seconds: 10));

  @override
  Future<void> rewind() =>
      _service.seek(_service.state.position - const Duration(seconds: 10));

  @override
  Future<void> skipToQueueItem(int index) => _service.skipToIndex(index);

  @override
  Future<void> click([
    audio_service.MediaButton button = audio_service.MediaButton.media,
  ]) async {
    switch (button) {
      case audio_service.MediaButton.next:
        await skipToNext();
      case audio_service.MediaButton.previous:
        await skipToPrevious();
      case audio_service.MediaButton.media:
        if (_service.state.playing) {
          await pause();
        } else {
          await play();
        }
    }
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == likeActionName) await onLike?.call();
  }

  Future<void> close() => _subscription.cancel();
}
