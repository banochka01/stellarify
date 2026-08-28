import 'dart:async';
import 'dart:math';

import 'package:resonance/core/errors/app_exception.dart';
import 'package:resonance/core/playback/playback_engine.dart';
import 'package:resonance/core/playback/resolved_source_cache.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_session.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/repositories/playback_persistence.dart';
import 'package:resonance/domain/services/source_selection_policy.dart';
import 'package:resonance/providers/common/provider_registry.dart';

final class PlaybackService {
  factory PlaybackService({
    required PlaybackEngine engine,
    required ProviderRegistry providers,
    required SourceSelectionPolicy sourceSelectionPolicy,
    PlaybackPersistence? persistence,
    ResolvedSourceCache? sourceCache,
    AudioQuality quality = AudioQuality.high,
    Random? random,
  }) {
    return PlaybackService._(
      engine: engine,
      providers: providers,
      sourceSelectionPolicy: sourceSelectionPolicy,
      persistence: persistence,
      sourceCache: sourceCache,
      quality: quality,
      random: random,
    );
  }

  PlaybackService._({
    required this._engine,
    required this._providers,
    required this._sourceSelectionPolicy,
    required this._persistence,
    required ResolvedSourceCache? sourceCache,
    required this._quality,
    required Random? random,
  }) : _sourceCache = sourceCache ?? ResolvedSourceCache(),
       _random = random ?? Random() {
    _subscriptions.addAll([
      _engine.playing.listen(
        (playing) => _emit(_state.copyWith(playing: playing)),
      ),
      _engine.buffering.listen(
        (buffering) => _emit(_state.copyWith(buffering: buffering)),
      ),
      _engine.position.listen(
        (position) => _emit(_state.copyWith(position: position)),
      ),
      _engine.duration.listen(
        (duration) => _emit(_state.copyWith(duration: duration)),
      ),
      _engine.volume.listen((volume) => _emit(_state.copyWith(volume: volume))),
      _engine.completed.listen(_onCompleted),
      _engine.errors.listen((message) {
        unawaited(_recoverFromEngineError(message));
      }),
    ]);
  }

  final PlaybackEngine _engine;
  final ProviderRegistry _providers;
  final SourceSelectionPolicy _sourceSelectionPolicy;
  final PlaybackPersistence? _persistence;
  final ResolvedSourceCache _sourceCache;
  final AudioQuality _quality;
  final Random _random;
  final _states = StreamController<ResonancePlaybackState>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _lastSuccessfulProvider = <String, MusicProvider>{};

  ResonancePlaybackState _state = const ResonancePlaybackState();
  bool _recovering = false;
  bool _disposed = false;

  ResonancePlaybackState get state => _state;
  Stream<ResonancePlaybackState> get states => _states.stream;

  Future<void> initialize() async {
    final persisted = await _persistence?.load();
    if (persisted != null) {
      final safeIndex =
          persisted.currentIndex >= 0 &&
              persisted.currentIndex < persisted.queue.length
          ? persisted.currentIndex
          : (persisted.queue.isEmpty ? -1 : 0);
      _emit(
        _state.copyWith(
          queue: persisted.queue,
          currentIndex: safeIndex,
          volume: persisted.volume.clamp(0, 100),
        ),
      );
    }
    await _engine.setVolume(_state.volume);
  }

  Future<void> setQueue(
    List<UnifiedTrack> tracks, {
    int startIndex = 0,
    bool autoplay = false,
  }) async {
    final safeIndex = tracks.isEmpty
        ? -1
        : startIndex.clamp(0, tracks.length - 1);
    _emit(
      _state.copyWith(
        queue: List.unmodifiable(tracks),
        currentIndex: safeIndex,
        position: Duration.zero,
        duration: Duration.zero,
        errorMessage: null,
      ),
    );
    await _persist();
    if (autoplay && safeIndex >= 0) {
      await _openCurrent(play: true);
    }
  }

  Future<void> playTrack(UnifiedTrack track) async {
    final existingIndex = _state.queue.indexWhere(
      (candidate) => candidate.id == track.id,
    );
    if (existingIndex >= 0) {
      _emit(_state.copyWith(currentIndex: existingIndex));
    } else {
      _emit(
        _state.copyWith(
          queue: [..._state.queue, track],
          currentIndex: _state.queue.length,
        ),
      );
    }
    await _persist();
    await _openCurrent(play: true);
  }

  Future<void> play() async {
    if (_state.currentTrack == null) {
      return;
    }
    if (_state.activeAudioSource == null ||
        _state.activeAudioSource!.isExpired()) {
      await _openCurrent(play: true, start: _state.position);
      return;
    }
    await _engine.play();
  }

  Future<void> pause() => _engine.pause();

  Future<void> seek(Duration position) {
    final clamped = position < Duration.zero
        ? Duration.zero
        : (_state.duration > Duration.zero && position > _state.duration
              ? _state.duration
              : position);
    return _engine.seek(clamped);
  }

  Future<void> setVolume(double volume) async {
    final safeVolume = volume.clamp(0, 100).toDouble();
    _emit(_state.copyWith(volume: safeVolume));
    await _engine.setVolume(safeVolume);
    await _persist();
  }

  Future<void> setShuffle(bool enabled) async {
    _emit(_state.copyWith(shuffle: enabled));
    await _engine.setShuffle(enabled);
  }

  Future<void> setRepeatMode(PlaybackRepeatMode mode) async {
    _emit(_state.copyWith(repeatMode: mode));
    await _engine.setRepeatMode(mode);
  }

  Future<void> addToQueue(UnifiedTrack track) async {
    _emit(_state.copyWith(queue: [..._state.queue, track]));
    await _persist();
  }

  Future<void> playNext(UnifiedTrack track) async {
    final insertAt = (_state.currentIndex + 1).clamp(0, _state.queue.length);
    final queue = [..._state.queue]..insert(insertAt, track);
    _emit(_state.copyWith(queue: queue));
    await _persist();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _state.queue.length) {
      return;
    }
    final queue = [..._state.queue]..removeAt(index);
    var currentIndex = _state.currentIndex;
    if (queue.isEmpty) {
      currentIndex = -1;
    } else if (index < currentIndex) {
      currentIndex -= 1;
    } else if (currentIndex >= queue.length) {
      currentIndex = queue.length - 1;
    }
    _emit(_state.copyWith(queue: queue, currentIndex: currentIndex));
    await _persist();
  }

  Future<void> next() async {
    if (_state.queue.isEmpty) {
      return;
    }
    if (_state.shuffle && _state.queue.length > 1) {
      var nextIndex = _state.currentIndex;
      while (nextIndex == _state.currentIndex) {
        nextIndex = _random.nextInt(_state.queue.length);
      }
      _emit(_state.copyWith(currentIndex: nextIndex));
      await _openCurrent(play: true);
      await _persist();
      return;
    }

    final candidate = _state.currentIndex + 1;
    if (candidate < _state.queue.length) {
      _emit(_state.copyWith(currentIndex: candidate));
      await _openCurrent(play: true);
    } else if (_state.repeatMode == PlaybackRepeatMode.all) {
      _emit(_state.copyWith(currentIndex: 0));
      await _openCurrent(play: true);
    } else {
      await pause();
      await seek(Duration.zero);
    }
    await _persist();
  }

  Future<void> previous() async {
    if (_state.queue.isEmpty) {
      return;
    }
    if (_state.position > const Duration(seconds: 5)) {
      await seek(Duration.zero);
      return;
    }
    final candidate = _state.currentIndex - 1;
    if (candidate >= 0) {
      _emit(_state.copyWith(currentIndex: candidate));
      await _openCurrent(play: true);
    } else if (_state.repeatMode == PlaybackRepeatMode.all) {
      _emit(_state.copyWith(currentIndex: _state.queue.length - 1));
      await _openCurrent(play: true);
    } else {
      await seek(Duration.zero);
    }
    await _persist();
  }

  Future<void> _openCurrent({
    required bool play,
    Duration start = Duration.zero,
  }) async {
    final track = _state.currentTrack;
    if (track == null) {
      return;
    }
    final sources = _sourceSelectionPolicy.orderedSources(
      track,
      lastSuccessfulProvider: _lastSuccessfulProvider[track.id],
    );
    final failures = <String>[];

    _emit(_state.copyWith(buffering: true, errorMessage: null));
    for (final source in sources) {
      final resolver = _providers.resolverFor(source.provider);
      if (resolver == null) {
        failures.add('${source.provider.name}: resolver не подключён');
        continue;
      }
      try {
        var resolved = _sourceCache.get(source);
        resolved ??= await resolver.resolve(source, quality: _quality);
        if (resolved.isExpired()) {
          _sourceCache.invalidate(source);
          resolved = await resolver.resolve(source, quality: _quality);
        }
        _sourceCache.put(source, resolved);
        await _engine.open(resolved, play: play, start: start);
        _lastSuccessfulProvider[track.id] = source.provider;
        _emit(
          _state.copyWith(
            activeTrackSource: source,
            activeAudioSource: resolved,
            buffering: false,
            playing: play,
            position: start,
            errorMessage: null,
          ),
        );
        return;
      } on Object catch (error) {
        _sourceCache.invalidate(source);
        failures.add('${source.provider.name}: $error');
      }
    }

    final message = failures.isEmpty
        ? 'У трека нет доступных источников.'
        : 'Не удалось воспроизвести трек. ${failures.join('; ')}';
    _emit(
      _state.copyWith(playing: false, buffering: false, errorMessage: message),
    );
    throw PlaybackFailedException(message);
  }

  void _onCompleted(bool completed) {
    if (!completed) {
      return;
    }
    if (_state.repeatMode == PlaybackRepeatMode.one) {
      unawaited(seek(Duration.zero).then((_) => play()));
    } else {
      unawaited(next());
    }
  }

  Future<void> _recoverFromEngineError(String message) async {
    if (_recovering || _state.currentTrack == null) {
      return;
    }
    _recovering = true;
    final position = _state.position;
    final active = _state.activeTrackSource;
    if (active != null) {
      _sourceCache.invalidate(active);
    }
    try {
      await _openCurrent(play: true, start: position);
    } on Object {
      _emit(
        _state.copyWith(
          errorMessage: 'Воспроизведение прервано: $message',
          playing: false,
          buffering: false,
        ),
      );
    } finally {
      _recovering = false;
    }
  }

  Future<void> _persist() async {
    await _persistence?.save(
      PlaybackSession(
        queue: _state.queue,
        currentIndex: _state.currentIndex,
        volume: _state.volume,
      ),
    );
  }

  void _emit(ResonancePlaybackState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _engine.dispose();
    await _states.close();
  }
}
