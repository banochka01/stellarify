import 'dart:async';

/// Manual DJ crossfade: the host/DJ fades the current track out, switches,
/// and fades the next one in. The target volume is read on every step, so a
/// volume change made by the user during the crossfade wins.
final class DjCrossfader {
  const DjCrossfader({this.steps = 12});

  final int steps;

  /// [setVolume] returns false when the player refuses (e.g. its own fade is
  /// running) — the crossfade then just switches the track.
  Future<void> run({
    required double Function() volume,
    required Duration duration,
    required Future<bool> Function(double volume) setVolume,
    required Future<void> Function() switchTrack,
    required Future<void> Function() restore,
    Future<void> Function(Duration) wait = Future<void>.delayed,
  }) async {
    final half = duration ~/ 2;
    final step = steps <= 0 ? Duration.zero : half ~/ steps;
    var fading = true;
    try {
      for (var index = steps - 1; index >= 0 && fading; index--) {
        fading = await setVolume(volume() * index / steps);
        if (fading) await wait(step);
      }
      await switchTrack();
      for (var index = 1; index < steps && fading; index++) {
        fading = await setVolume(volume() * index / steps);
        if (fading) await wait(step);
      }
    } finally {
      await restore();
    }
  }
}
