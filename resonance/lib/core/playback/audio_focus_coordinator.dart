import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:resonance/core/playback/playback_service.dart';

final class AudioFocusCoordinator {
  AudioFocusCoordinator(this._playbackService);

  final PlaybackService _playbackService;
  final _subscriptions = <StreamSubscription<Object?>>[];

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          unawaited(_playbackService.pause());
        }
      }),
    );
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) {
        unawaited(_playbackService.pause());
      }),
    );
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
