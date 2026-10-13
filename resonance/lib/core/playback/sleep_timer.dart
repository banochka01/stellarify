import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/playback_state.dart';

/// То, что нужно таймеру сна от плеера; `PlaybackService` подходит как есть.
abstract interface class SleepTimerPlayback {
  ResonancePlaybackState get state;
  Stream<ResonancePlaybackState> get states;
  Future<void> fadeOutAndPause({Duration duration});

  /// Просит плеер остановиться после текущего трека, не начиная следующий.
  void setStopAfterCurrent(bool value);
}

/// Докуда играть в режиме «до конца»: трек, альбом или вся очередь.
enum SleepTimerScope { track, album, queue }

/// Последний трек, после которого нужно остановиться: для альбома — конец
/// непрерывного отрезка того же альбома в очереди, для очереди — её конец.
String? sleepTimerTargetTrackId(
  ResonancePlaybackState playback,
  SleepTimerScope scope,
) {
  final queue = playback.queue;
  final index = playback.currentIndex;
  if (index < 0 || index >= queue.length) return null;
  switch (scope) {
    case SleepTimerScope.track:
      return queue[index].id;
    case SleepTimerScope.queue:
      return queue.last.id;
    case SleepTimerScope.album:
      final album = queue[index].album?.trim().toLowerCase();
      if (album == null || album.isEmpty) return queue[index].id;
      var last = index;
      while (last + 1 < queue.length &&
          queue[last + 1].album?.trim().toLowerCase() == album) {
        last++;
      }
      return queue[last].id;
  }
}

final class SleepTimerState {
  const SleepTimerState({
    this.endsAt,
    this.endOfTrackId,
    this.fading = false,
    this.scope = SleepTimerScope.track,
  });

  /// Момент, когда начнётся затухание (режим «через N минут»).
  final DateTime? endsAt;

  /// Трек, после которого нужно остановиться (режим «в конце трека»).
  final String? endOfTrackId;
  final bool fading;

  /// Для режима «до конца»: трек, альбом или очередь.
  final SleepTimerScope scope;

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

  /// Номер текущего запуска: завершение старого затухания не должно сбросить
  /// таймер, который человек успел завести заново.
  int _generation = 0;
  SleepTimerPlayback? _armedPlayback;

  /// Останавливает музыку через [after]; затухание укладывается в конец срока.
  Future<void> startFor(Duration after) async {
    cancel();
    final generation = _generation;
    state = SleepTimerState(endsAt: _clock().add(after));
    final fadeAt = after > fadeDuration ? after - fadeDuration : Duration.zero;
    _timer = Timer(fadeAt, () => unawaited(_fire(generation)));
  }

  /// Останавливает музыку, когда закончится текущий трек.
  Future<void> startEndOfTrack() => startEndOf(SleepTimerScope.track);

  /// Останавливает музыку в конце трека, альбома или всей очереди
  /// (плейлиста); последние секунды плавно затухают.
  Future<void> startEndOf(SleepTimerScope scope) async {
    cancel();
    final generation = _generation;
    final playback = await _playback();
    if (_disposed || generation != _generation) return;
    final trackId = sleepTimerTargetTrackId(playback.state, scope);
    if (trackId == null) return;
    state = SleepTimerState(endOfTrackId: trackId, scope: scope);
    _armedPlayback = playback
      ..setStopAfterCurrent(playback.state.currentTrack?.id == trackId);
    _subscription = playback.states.listen(
      (value) => _watchTrackEnd(value, generation),
    );
    _watchTrackEnd(playback.state, generation);
  }

  void _watchTrackEnd(ResonancePlaybackState playback, int generation) {
    final armed = state.endOfTrackId;
    if (armed == null || state.fading || generation != _generation) return;
    final current = playback.currentTrack?.id;
    if (current != armed) {
      final target = playback.queue.indexWhere((track) => track.id == armed);
      if (target > playback.currentIndex && playback.currentIndex >= 0) {
        // Альбом или очередь ещё не доиграли — ждём последний трек.
        _armedPlayback?.setStopAfterCurrent(false);
        return;
      }
      // Последний трек уже пропущен — останавливаемся сразу.
      unawaited(_fire(generation, fade: const Duration(seconds: 2)));
      return;
    }
    _armedPlayback?.setStopAfterCurrent(true);
    if (!playback.playing && playback.position > Duration.zero) {
      final duration = playback.duration;
      // Плеер сам встал на паузу в конце трека — таймер выполнил работу.
      if (duration > Duration.zero &&
          duration - playback.position < const Duration(seconds: 2)) {
        _finish(generation);
      }
      return;
    }
    final duration = playback.duration;
    if (duration <= Duration.zero) return;
    final left = duration - playback.position;
    final fade = fadeDuration ~/ 2;
    if (left <= fade) unawaited(_fire(generation, fade: left));
  }

  void _finish(int generation) {
    if (generation != _generation) return;
    _generation++;
    _timer?.cancel();
    _timer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _armedPlayback?.setStopAfterCurrent(false);
    _armedPlayback = null;
    if (!_disposed) state = const SleepTimerState();
  }

  Future<void> _fire(int generation, {Duration? fade}) async {
    if (_disposed || state.fading || generation != _generation) return;
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
      _armedPlayback?.setStopAfterCurrent(false);
      _armedPlayback = null;
      if (!_disposed && generation == _generation) {
        state = const SleepTimerState();
      }
    }
  }

  /// Снимает таймер. Уже начатое затухание доигрывается, но новый запуск
  /// после этого не будет сброшен его завершением.
  void cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _armedPlayback?.setStopAfterCurrent(false);
    _armedPlayback = null;
    state = const SleepTimerState();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _armedPlayback?.setStopAfterCurrent(false);
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
