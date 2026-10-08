import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/recap/listening_recap.dart';

/// Куда записывать прослушивания; `AppDatabase` подходит как есть.
abstract interface class ListeningStore {
  Future<int> recordListen(UnifiedTrack track, Duration listened);
  Future<void> updateListen(int id, Duration listened);
}

/// Считает, сколько каждый трек реально звучал, и пишет это в историю.
///
/// Прослушивание засчитывается после 30 секунд (или половины короткого
/// трека); дальше запись только уточняется. Перемотка вперёд не добавляет
/// времени — считаются лишь плавные шаги позиции во время игры.
final class ListeningRecorder {
  ListeningRecorder(this._store, {this.onRecorded});

  /// Вызывается, когда в истории появилось новое прослушивание.
  final void Function()? onRecorded;

  static const threshold = Duration(seconds: 30);
  static const _maxStep = Duration(seconds: 3);

  final ListeningStore _store;
  UnifiedTrack? _track;
  Duration _listened = Duration.zero;
  Duration? _lastPosition;
  Future<int>? _entry;
  Duration _savedListened = Duration.zero;

  void onPlayback(ResonancePlaybackState playback) {
    final track = playback.currentTrack;
    if (track?.id != _track?.id) {
      unawaited(_flush());
      _track = track;
      _listened = Duration.zero;
      _savedListened = Duration.zero;
      _lastPosition = playback.position;
      _entry = null;
      return;
    }
    if (track == null) return;
    final last = _lastPosition;
    _lastPosition = playback.position;
    if (!playback.playing || last == null) return;
    final step = playback.position - last;
    if (step <= Duration.zero || step > _maxStep) return;
    _listened += step;
    if (_entry == null && _listened >= _thresholdFor(playback)) {
      _savedListened = _listened;
      _entry = _store.recordListen(track, _listened);
      unawaited(
        _entry!.then(
          (_) => onRecorded?.call(),
          onError: (Object _) => _entry = null,
        ),
      );
    } else if (_entry != null &&
        _listened - _savedListened >= const Duration(seconds: 30)) {
      unawaited(_flush());
    }
  }

  Duration _thresholdFor(ResonancePlaybackState playback) {
    final duration = playback.duration;
    if (duration > Duration.zero && duration < threshold * 2) {
      final half = duration ~/ 2;
      return half < const Duration(seconds: 10)
          ? const Duration(seconds: 10)
          : half;
    }
    return threshold;
  }

  Future<void> _flush() async {
    final entry = _entry;
    if (entry == null || _listened <= _savedListened) return;
    final listened = _listened;
    _savedListened = listened;
    try {
      await _store.updateListen(await entry, listened);
    } on Object {
      // История — приятное дополнение; плеер от неё не зависит.
    }
  }

  Future<void> dispose() => _flush();
}

final listeningRecorderProvider = FutureProvider<ListeningRecorder>((
  ref,
) async {
  final database = ref.watch(appDatabaseProvider);
  final recorder = ListeningRecorder(
    _DatabaseListeningStore(database),
    onRecorded: () => ref.invalidate(listeningRecapProvider),
  );
  final service = await ref.watch(playbackServiceProvider.future);
  recorder.onPlayback(service.state);
  final subscription = service.states.listen(recorder.onPlayback);
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(recorder.dispose());
  });
  return recorder;
});

final class _DatabaseListeningStore implements ListeningStore {
  const _DatabaseListeningStore(this._database);

  final AppDatabase _database;

  @override
  Future<int> recordListen(UnifiedTrack track, Duration listened) =>
      _database.recordListen(track, listened);

  @override
  Future<void> updateListen(int id, Duration listened) =>
      _database.updateListen(id, listened);
}
