import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/core/playback/sleep_timer.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';

void main() {
  test('fades out and pauses when the countdown ends', () async {
    final playback = _FakePlayback(_playing(demoTrack));
    final timer = SleepTimerController(
      () async => playback,
      fadeDuration: const Duration(milliseconds: 20),
    );
    addTearDown(timer.dispose);

    await timer.startFor(const Duration(milliseconds: 60));
    expect(timer.state.active, isTrue);
    expect(timer.state.endsAt, isNotNull);

    await _waitUntil(() => playback.fades.isNotEmpty && !timer.state.active);
    expect(playback.fades.single, const Duration(milliseconds: 20));
  });

  test('cancel stops a pending countdown', () async {
    final playback = _FakePlayback(_playing(demoTrack));
    final timer = SleepTimerController(
      () async => playback,
      fadeDuration: const Duration(milliseconds: 10),
    );
    addTearDown(timer.dispose);

    await timer.startFor(const Duration(milliseconds: 40));
    timer.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(playback.fades, isEmpty);
    expect(timer.state.active, isFalse);
  });

  test('a timer started during a fade survives the old fade', () async {
    final playback = _FakePlayback(_playing(demoTrack))
      ..fadeGate = Completer<void>();
    final timer = SleepTimerController(
      () async => playback,
      fadeDuration: Duration.zero,
    );
    addTearDown(timer.dispose);

    await timer.startFor(Duration.zero);
    await _waitUntil(() => timer.state.fading);
    await timer.startFor(const Duration(minutes: 30));
    playback.fadeGate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(timer.state.endsAt, isNotNull);
    expect(timer.state.active, isTrue);
  });

  test('end of track asks the player not to start the next track', () async {
    final playback = _FakePlayback(_playing(demoTrack));
    final timer = SleepTimerController(() async => playback);
    addTearDown(timer.dispose);

    await timer.startEndOfTrack();
    expect(playback.stopAfterCurrent, isTrue);
    timer.cancel();
    expect(playback.stopAfterCurrent, isFalse);
  });

  test('end of track pauses before the next track starts', () async {
    final playback = _FakePlayback(
      _playing(demoTrack, position: const Duration(seconds: 10)),
    );
    final timer = SleepTimerController(
      () async => playback,
      fadeDuration: const Duration(seconds: 12),
    );
    addTearDown(timer.dispose);

    await timer.startEndOfTrack();
    expect(timer.state.endOfTrack, isTrue);
    playback.emit(_playing(demoTrack, position: const Duration(seconds: 115)));
    await _waitUntil(() => playback.fades.isNotEmpty);
    expect(playback.fades.single, const Duration(seconds: 5));
  });

  test('end of track stops at once when the track was skipped', () async {
    final playback = _FakePlayback(_playing(demoTrack));
    final timer = SleepTimerController(() async => playback);
    addTearDown(timer.dispose);

    await timer.startEndOfTrack();
    playback.emit(_playing(demoTrack.copyWith(id: 'other')));
    await _waitUntil(() => playback.fades.isNotEmpty);
    expect(playback.fades.single, const Duration(seconds: 2));
  });
}

ResonancePlaybackState _playing(
  UnifiedTrack track, {
  Duration position = Duration.zero,
}) => ResonancePlaybackState(
  queue: [track],
  currentIndex: 0,
  playing: true,
  position: position,
  duration: const Duration(minutes: 2),
);

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not reached in time');
}

final class _FakePlayback implements SleepTimerPlayback {
  _FakePlayback(this._state);

  ResonancePlaybackState _state;
  final _controller = StreamController<ResonancePlaybackState>.broadcast();
  final fades = <Duration>[];
  bool stopAfterCurrent = false;

  @override
  void setStopAfterCurrent(bool value) => stopAfterCurrent = value;

  void emit(ResonancePlaybackState value) {
    _state = value;
    _controller.add(value);
  }

  @override
  ResonancePlaybackState get state => _state;

  @override
  Stream<ResonancePlaybackState> get states => _controller.stream;

  Completer<void>? fadeGate;

  @override
  Future<void> fadeOutAndPause({
    Duration duration = const Duration(seconds: 12),
  }) async {
    fades.add(duration);
    await fadeGate?.future;
  }
}
