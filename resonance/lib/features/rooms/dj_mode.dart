import 'dart:async';

/// Manual DJ crossfade: the host/DJ fades the current track out, switches,
/// and fades the next one in. Volume steps are used because the playback
/// engine owns a single player; the room controller then syncs the new track.
final class DjCrossfader {
  const DjCrossfader({this.steps = 12});

  final int steps;

  Future<void> run({
    required double volume,
    required Duration duration,
    required Future<void> Function(double volume) setVolume,
    required Future<void> Function() switchTrack,
    Future<void> Function(Duration) wait = Future<void>.delayed,
  }) async {
    final half = duration ~/ 2;
    final step = steps <= 0 ? Duration.zero : half ~/ steps;
    try {
      for (var index = steps - 1; index >= 0; index--) {
        await setVolume(volume * index / steps);
        await wait(step);
      }
      await switchTrack();
      for (var index = 1; index < steps; index++) {
        await setVolume(volume * index / steps);
        await wait(step);
      }
    } finally {
      await setVolume(volume);
    }
  }
}
