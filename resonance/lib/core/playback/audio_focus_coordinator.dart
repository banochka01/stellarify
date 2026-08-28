import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:resonance/core/playback/playback_service.dart';

final class AudioFocusCoordinator {
  AudioFocusCoordinator(this._playbackService);

  final PlaybackService _playbackService;
  final _subscriptions = <StreamSubscription<Object?>>[];
  AudioSession? _session;
  bool _resumeAfterInterruption = false;

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    _session = session;
    await session.configure(const AudioSessionConfiguration.music());
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          _resumeAfterInterruption = _playbackService.state.playing;
          unawaited(_playbackService.pause());
        } else if (_resumeAfterInterruption) {
          _resumeAfterInterruption = false;
          unawaited(_playbackService.play());
        }
      }),
    );
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) {
        _resumeAfterInterruption = false;
        unawaited(_playbackService.pause());
      }),
    );
    _subscriptions.add(
      _playbackService.states.map((state) => state.playing).distinct().listen((
        playing,
      ) {
        unawaited(session.setActive(playing));
      }),
    );
    if (_playbackService.state.playing) {
      await session.setActive(true);
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _session?.setActive(false);
  }
}
