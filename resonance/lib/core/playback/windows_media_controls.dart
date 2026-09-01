import 'dart:async';
import 'dart:developer';

import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:smtc_windows/smtc_windows.dart';

final class WindowsMediaControls {
  WindowsMediaControls._(this._service) {
    _smtc = SMTCWindows(
      config: const SMTCConfig(
        playEnabled: true,
        pauseEnabled: true,
        nextEnabled: true,
        prevEnabled: true,
        stopEnabled: false,
        fastForwardEnabled: true,
        rewindEnabled: true,
      ),
    );
    _subscriptions.add(_smtc.buttonPressStream.listen(_handleButton));
    _subscriptions.add(_service.states.listen(_publish));
    _publish(_service.state);
  }

  static bool _available = false;

  static Future<bool> initialize() async {
    try {
      await SMTCWindows.initialize();
      _available = true;
    } catch (error, stackTrace) {
      _available = false;
      log(
        'Windows media controls are unavailable; startup will continue.',
        name: 'resonance.windows_media_controls',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return _available;
  }

  static WindowsMediaControls? tryCreate(PlaybackService service) {
    if (!_available) return null;
    try {
      return WindowsMediaControls._(service);
    } catch (error, stackTrace) {
      log(
        'Windows media controls could not be created.',
        name: 'resonance.windows_media_controls',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  final PlaybackService _service;
  late final SMTCWindows _smtc;
  final _subscriptions = <StreamSubscription<Object?>>[];
  String? _trackId;
  bool? _playing;
  int _positionSecond = -1;

  void _handleButton(PressedButton button) {
    unawaited(switch (button) {
      PressedButton.play => _service.play(),
      PressedButton.pause => _service.pause(),
      PressedButton.next => _service.next(),
      PressedButton.previous => _service.previous(),
      PressedButton.fastForward => _service.seek(
        _service.state.position + const Duration(seconds: 10),
      ),
      PressedButton.rewind => _service.seek(
        _service.state.position - const Duration(seconds: 10),
      ),
      _ => Future<void>.value(),
    });
  }

  void _publish(ResonancePlaybackState state) {
    final track = state.currentTrack;
    final trackChanged = track != null && track.id != _trackId;
    if (trackChanged) {
      _trackId = track.id;
      unawaited(
        _smtc.updateMetadata(
          MusicMetadata(
            title: track.title,
            artist: track.artist,
            album: track.album,
            albumArtist: track.artist,
            thumbnail: track.artworkUrl?.toString(),
          ),
        ),
      );
    }
    if (state.playing != _playing) {
      _playing = state.playing;
      unawaited(
        _smtc.setPlaybackStatus(
          state.playing ? PlaybackStatus.playing : PlaybackStatus.paused,
        ),
      );
    }
    final second = state.position.inSeconds;
    if (second != _positionSecond || trackChanged) {
      _positionSecond = second;
      final duration = state.duration.inMilliseconds.clamp(0, 1 << 31);
      unawaited(
        _smtc.updateTimeline(
          PlaybackTimeline(
            startTimeMs: 0,
            endTimeMs: duration,
            positionMs: state.position.inMilliseconds.clamp(0, duration),
            minSeekTimeMs: 0,
            maxSeekTimeMs: duration,
          ),
        ),
      );
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _smtc.dispose();
  }
}
