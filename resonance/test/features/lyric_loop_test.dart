import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/core/playback/lyric_loop_playback.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/features/lyrics/lyric_loop.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';

const _lines = [
  LyricLine(text: 'one', start: Duration(seconds: 10)),
  LyricLine(text: 'two', start: Duration(seconds: 14)),
  LyricLine(text: 'three', start: Duration(seconds: 20)),
];

void main() {
  test('a line loops until the start of the next line', () {
    final loop = lyricLoopFor('t', _lines, 1, const Duration(minutes: 3))!;
    expect(loop.start, const Duration(seconds: 14));
    expect(loop.end, const Duration(seconds: 20));
  });

  test('the last line loops for a few seconds within the track', () {
    final loop = lyricLoopFor('t', _lines, 2, const Duration(seconds: 24))!;
    expect(loop.end, const Duration(seconds: 23));
    expect(lyricLoopFor('t', _lines, 5, Duration.zero), isNull);
  });

  test(
    'controller seeks back at the loop end and clears on track change',
    () async {
      final playback = _FakePlayback();
      final controller = LyricLoopController(() async => playback);
      addTearDown(controller.dispose);

      final loop = lyricLoopFor(demoTrack.id, _lines, 0, Duration.zero)!;
      await controller.toggle(loop);
      expect(playback.seeks, [const Duration(seconds: 10)]);

      playback.emit(const Duration(seconds: 14));
      await Future<void>.delayed(Duration.zero);
      expect(playback.seeks.last, const Duration(seconds: 10));

      playback.emit(const Duration(seconds: 11), trackId: 'other');
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isNull);
    },
  );

  test('toggling the same line removes the loop', () async {
    final controller = LyricLoopController(() async => _FakePlayback());
    addTearDown(controller.dispose);
    final loop = lyricLoopFor(demoTrack.id, _lines, 0, Duration.zero)!;
    await controller.toggle(loop);
    await controller.toggle(loop);
    expect(controller.state, isNull);
  });
}

final class _FakePlayback implements LyricLoopPlayback {
  final _controller = StreamController<ResonancePlaybackState>.broadcast();
  final seeks = <Duration>[];
  ResonancePlaybackState _state = ResonancePlaybackState(
    queue: [demoTrack],
    currentIndex: 0,
    playing: true,
  );

  void emit(Duration position, {String? trackId}) {
    final track = trackId == null ? demoTrack : demoTrack.copyWith(id: trackId);
    _state = _state.copyWith(queue: [track], position: position);
    _controller.add(_state);
  }

  @override
  ResonancePlaybackState get state => _state;

  @override
  Stream<ResonancePlaybackState> get states => _controller.stream;

  @override
  Future<void> seek(Duration position) async => seeks.add(position);
}
