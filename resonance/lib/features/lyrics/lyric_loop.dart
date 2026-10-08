import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/lyric_loop_playback.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';

/// Повтор строки: удобно разучивать куплет. Петля живёт только на своём
/// треке и снимается сама, когда трек меняется.
final class LyricLoop {
  const LyricLoop({
    required this.trackId,
    required this.index,
    required this.start,
    required this.end,
  });

  final String trackId;
  final int index;
  final Duration start;
  final Duration end;
}

/// Петля для строки [index]: от её начала до начала следующей строки.
/// У последней строки берём до 8 секунд, но не дальше конца трека.
LyricLoop? lyricLoopFor(
  String trackId,
  List<LyricLine> lines,
  int index,
  Duration trackDuration,
) {
  if (index < 0 || index >= lines.length) return null;
  final start = lines[index].start;
  if (start == null) return null;
  Duration? end;
  for (var next = index + 1; next < lines.length; next++) {
    final candidate = lines[next].start;
    if (candidate != null && candidate > start) {
      end = candidate;
      break;
    }
  }
  end ??= start + const Duration(seconds: 8);
  // Последняя строка: оставляем секунду до конца, иначе трек успеет
  // закончиться и переключиться раньше, чем петля вернётся назад.
  final limit = trackDuration - const Duration(seconds: 1);
  if (trackDuration > Duration.zero && end > limit) end = limit;
  if (end - start < const Duration(milliseconds: 800)) return null;
  return LyricLoop(trackId: trackId, index: index, start: start, end: end);
}

final class LyricLoopController extends StateNotifier<LyricLoop?> {
  LyricLoopController(this._playback) : super(null);

  final Future<LyricLoopPlayback> Function() _playback;
  StreamSubscription<ResonancePlaybackState>? _subscription;
  bool _seeking = false;

  Future<void> toggle(LyricLoop loop) async {
    final current = state;
    if (current != null &&
        current.trackId == loop.trackId &&
        current.index == loop.index) {
      clear();
      return;
    }
    state = loop;
    final playback = await _playback();
    if (state != loop) return;
    await _subscription?.cancel();
    _subscription = playback.states.listen(
      (value) => _onPlayback(playback, value),
    );
    await playback.seek(loop.start);
  }

  void _onPlayback(LyricLoopPlayback playback, ResonancePlaybackState value) {
    final loop = state;
    if (loop == null) return;
    if (value.currentTrack?.id != loop.trackId) {
      clear();
      return;
    }
    if (_seeking) return;
    // Небольшой запас: позиция приходит тиками, и петля не должна
    // проскакивать первые слоги следующей строки.
    if (value.position >= loop.end - const Duration(milliseconds: 120) ||
        value.position < loop.start - const Duration(seconds: 2)) {
      _seeking = true;
      unawaited(playback.seek(loop.start).whenComplete(() => _seeking = false));
    }
  }

  void clear() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    state = null;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final lyricLoopProvider =
    StateNotifierProvider<LyricLoopController, LyricLoop?>((ref) {
      return LyricLoopController(
        () => ref
            .read(playbackServiceProvider.future)
            .then<LyricLoopPlayback>((service) => service),
      );
    });

/// Включает или снимает повтор строки [index] текущего трека.
void toggleLyricLoop(
  WidgetRef ref, {
  required String trackId,
  required List<LyricLine> lines,
  required int index,
  required Duration trackDuration,
}) {
  final loop = lyricLoopFor(trackId, lines, index, trackDuration);
  if (loop == null) return;
  unawaited(ref.read(lyricLoopProvider.notifier).toggle(loop));
}
