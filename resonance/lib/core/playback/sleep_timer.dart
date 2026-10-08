import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/playback_state.dart';

/// То, что нужно таймеру сна от плеера; `PlaybackService` подходит как есть.
abstract interface class SleepTimerPlayback {
  ResonancePlaybackState get state;
  Stream<ResonancePlaybackState> get states;
  Future<void> fadeOutAndPause({Duration duration});
}

final class SleepTimerState {
  const SleepTimerState({this.endsAt, this.endOfTrackId, this.fading = false});

  /// Момент, когда начнётся затухание (режим «через N минут»).
  final DateTime? endsAt;

  /// Трек, после которого нужно остановиться (режим «в конце трека»).
  final String? endOfTrackId;
  final bool fading;

  bool get active => endsAt != null || endOfTrackId != null || fading;
  bool get endOfTrack => endOfTrackId != null;

  Duration remaining(DateTime now) {
    final ends = endsAt;
    if (ends == null) return Duration.zero;
    final left = ends.difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}

final class SleepTimerController extends StateNotifier<SleepTimerState> {
  SleepTimerController(
    this._playback, {
    this.fadeDuration = const Duration(seconds: 12),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const SleepTimerState());

  static const presets = <Duration>[
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(minutes: 60),
  ];

  final Future<SleepTimerPlayback> Function() _playback;
  final Duration fadeDuration;
  final DateTime Function() _clock;
  Timer? _timer;
  StreamSubscription<ResonancePlaybackState>? _subscription;
  bool _disposed = false;

  /// Останавливает музыку через [after]; затухание укладывается в конец срока.
  Future<void> startFor(Duration after) async {
    cancel();
    state = SleepTimerState(endsAt: _clock().add(after));
    final fadeAt = after > fadeDuration ? after - fadeDuration : Duration.zero;
    _timer = Timer(fadeAt, () => unawaited(_fire()));
  }

  /// Останавливает музыку, когда закончится текущий трек.
  Future<void> startEndOfTrack() async {
    cancel();
    final playback = await _playback();
    if (_disposed) return;
    final trackId = playback.state.currentTrack?.id;
    if (trackId == null) return;
    state = SleepTimerState(endOfTrackId: trackId);
    _subscription = playback.states.listen(_watchTrackEnd);
    _watchTrackEnd(playback.state);
  }

  void _watchTrackEnd(ResonancePlaybackState playback) {
    final armed = state.endOfTrackId;
    if (armed == null || state.fading) return;
    final current = playback.currentTrack?.id;
    if (current != armed) {
      // Трек уже сменился (пропуск или ручной выбор) — останавливаемся сразу.
      unawaited(_fire(fade: const Duration(seconds: 2)));
      return;
    }
    final duration = playback.duration;
    if (duration <= Duration.zero) return;
    final left = duration - playback.position;
    final fade = fadeDuration ~/ 2;
    if (left <= fade) unawaited(_fire(fade: left));
  }

  Future<void> _fire({Duration? fade}) async {
    if (_disposed || state.fading) return;
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    state = const SleepTimerState(fading: true);
    try {
      final playback = await _playback();
      await playback.fadeOutAndPause(duration: fade ?? fadeDuration);
    } on Object {
      // Таймер сна не должен ронять плеер.
    } finally {
      if (!_disposed) state = const SleepTimerState();
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (!state.fading) state = const SleepTimerState();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
