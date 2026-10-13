import 'dart:async';
import 'dart:math';

import 'package:resonance/core/errors/app_exception.dart';
import 'package:resonance/core/playback/loudness_normalization.dart';
import 'package:resonance/core/playback/lyric_loop_playback.dart';
import 'package:resonance/core/playback/offline_downloads.dart';
import 'package:resonance/core/playback/playback_engine.dart';
import 'package:resonance/core/playback/resolved_source_cache.dart';
import 'package:resonance/core/playback/sleep_timer.dart';
import 'package:resonance/core/playback/transition_policy.dart';
import 'package:resonance/core/preferences/playback_flow_preferences.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_session.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/repositories/playback_persistence.dart';
import 'package:resonance/domain/services/source_selection_policy.dart';
import 'package:resonance/providers/common/provider_registry.dart';

final class PlaybackService implements SleepTimerPlayback, LyricLoopPlayback {
  factory PlaybackService({
    required PlaybackEngine engine,
    required ProviderRegistry providers,
    required SourceSelectionPolicy sourceSelectionPolicy,
    PlaybackPersistence? persistence,
    OfflineDownloads? offlineDownloads,
    ResolvedSourceCache? sourceCache,
    AudioQuality quality = AudioQuality.high,
    Random? random,
    Future<void> Function(MusicProvider)? authorizeSource,
    PlaybackFlowSettings flowSettings = const PlaybackFlowSettings(),
    LoudnessNormalizer? normalizer,
  }) {
    return PlaybackService._(
      normalizer: normalizer ?? LoudnessNormalizer(null),
      engine: engine,
      providers: providers,
      sourceSelectionPolicy: sourceSelectionPolicy,
      persistence: persistence,
      offlineDownloads: offlineDownloads,
      sourceCache: sourceCache,
      quality: quality,
      random: random,
      authorizeSource: authorizeSource,
      flowSettings: flowSettings,
    );
  }

  PlaybackService._({
    required this._engine,
    required this._providers,
    required this._sourceSelectionPolicy,
    required this._persistence,
    required this._offlineDownloads,
    required ResolvedSourceCache? sourceCache,
    required this._quality,
    required Random? random,
    required this._authorizeSource,
    required this._flowSettings,
    required this._normalizer,
  }) : _sourceCache = sourceCache ?? ResolvedSourceCache(),
       _random = random ?? Random() {
    _subscriptions.addAll([
      _engine.playing.listen((playing) {
        if (!playing) _accessTimer?.cancel();
        _emit(_state.copyWith(playing: playing));
        if (playing) _scheduleAccessCheck();
      }),
      _engine.buffering.listen(
        (buffering) => _emit(_state.copyWith(buffering: buffering)),
      ),
      _engine.position.listen((position) {
        _emit(_state.copyWith(position: position));
        _maybePrefetchNext(position);
        _maybePrepareGapless(position);
        _maybeStartAutomaticFlow(position);
      }),
      _engine.duration.listen(
        (duration) => _emit(_state.copyWith(duration: duration)),
      ),
      _engine.volume.listen((volume) {
        if (!_transitioning && !_fading) _emit(_state.copyWith(volume: volume));
      }),
      _engine.completed.listen(_onCompleted),
      _engine.advancedToQueued.listen((_) => unawaited(_onGaplessAdvance())),
      _engine.errors.listen((message) {
        unawaited(_recoverFromEngineError(message));
      }),
    ]);
  }

  final Future<void> Function(MusicProvider)? _authorizeSource;
  Timer? _accessTimer;
  bool _checkingAccess = false;
  void _scheduleAccessCheck() {
    _accessTimer?.cancel();
    if (_authorizeSource == null ||
        _disposed ||
        !_state.playing ||
        _state.activeAudioSource?.streamUrl.isScheme('file') == true ||
        _state.activeTrackSource == null) {
      return;
    }
    _accessTimer = Timer(const Duration(seconds: 15), () async {
      await _checkActiveAccess();
      _scheduleAccessCheck();
    });
  }

  Future<void> _checkActiveAccess() async {
    final source = _state.activeTrackSource;
    if (!_state.playing ||
        source == null ||
        _checkingAccess ||
        _state.activeAudioSource?.streamUrl.isScheme('file') == true) {
      return;
    }
    _checkingAccess = true;
    try {
      await _authorizeSource?.call(source.provider);
    } on Object catch (_) {
      _sourceCache.clear();
      await _recoverFromEngineError(
        'доступ к ${_providerTitle(source.provider)} завершён',
      );
    } finally {
      _checkingAccess = false;
    }
  }

  final PlaybackEngine _engine;
  final ProviderRegistry _providers;
  final SourceSelectionPolicy _sourceSelectionPolicy;
  final PlaybackPersistence? _persistence;
  final OfflineDownloads? _offlineDownloads;
  final ResolvedSourceCache _sourceCache;
  AudioQuality _quality;
  final Random _random;
  final _states = StreamController<ResonancePlaybackState>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _lastSuccessfulProvider = <String, MusicProvider>{};
  final _prefetchingTrackIds = <String>{};
  PlaybackFlowSettings _flowSettings;
  final LoudnessNormalizer _normalizer;
  Timer? _sourceNoticeTimer;

  /// Следующий трек, уже поставленный в плеер для бесшовного перехода.
  ({
    int index,
    String trackId,
    TrackSource source,
    ResolvedAudioSource resolved,
  })?
  _gapless;
  bool _preparingGapless = false;
  double? _currentGainDb;

  /// Гейн выравнивания громкости текущего трека, дБ (`null` — нет оценки).
  double? get currentGainDb => _currentGainDb;

  ResonancePlaybackState _state = const ResonancePlaybackState();
  bool _recovering = false;
  bool _transitioning = false;
  bool _fading = false;
  bool _pauseAfterTransition = false;
  bool _stopAfterCurrent = false;
  int _fadeGeneration = 0;
  double? _volumeDuringFade;
  bool _disposed = false;

  @override
  ResonancePlaybackState get state => _state;
  @override
  Stream<ResonancePlaybackState> get states => _states.stream;

  AudioQuality get quality => _quality;

  PlaybackFlowSettings get flowSettings => _flowSettings;

  Future<void> setFlowSettings(PlaybackFlowSettings settings) async {
    final previous = _flowSettings;
    _flowSettings = settings;
    await _engine.setLoudnessNormalization(settings.normalizeLoudness);
    if (previous.normalization != settings.normalization) {
      final track = _state.currentTrack;
      final audio = _state.activeAudioSource;
      if (track != null && audio != null) await _applyGain(track, audio);
    }
    if (!settings.gapless ||
        previous.enabled != settings.enabled ||
        previous.transitionMs != settings.transitionMs ||
        previous.smartTransitions != settings.smartTransitions) {
      await _dropGapless();
    }
  }

  Future<void> _applyGain(UnifiedTrack track, ResolvedAudioSource audio) async {
    double? gain;
    try {
      gain = await _normalizer.gainFor(
        mode: _flowSettings.normalization,
        track: track,
        source: audio,
      );
    } on Object {
      gain = null;
    }
    // Пока считали, трек мог смениться.
    if (_disposed || _state.currentTrack?.id != track.id) return;
    _currentGainDb = gain;
    await _engine.setReplayGain(gain);
  }

  /// Перед сменой трека сохраняет громкость, измеренную плеером.
  Future<void> _captureLoudness() async {
    final track = _state.currentTrack;
    if (track == null ||
        !_flowSettings.normalizeLoudness ||
        _state.position < const Duration(seconds: 30)) {
      return;
    }
    try {
      final lufs = await _engine.measuredLoudnessLufs().timeout(
        const Duration(milliseconds: 300),
      );
      if (lufs != null) await _normalizer.remember(track, lufs);
    } on Object {
      // Измерение оппортунистично.
    }
  }

  bool _preloadNext = false;

  /// Предзагрузка следующего трека очереди целиком, пока играет текущий:
  /// на плохой сети переход не ждёт буферизации.
  bool get preloadNext => _preloadNext;

  void setPreloadNext(bool enabled) {
    _preloadNext = enabled;
    if (enabled) _preloadNextAudio();
  }

  void _preloadNextAudio() {
    final downloads = _offlineDownloads;
    if (!_preloadNext || downloads == null || _state.queue.isEmpty) return;
    final nextIndex = _state.currentIndex + 1 < _state.queue.length
        ? _state.currentIndex + 1
        : (_state.repeatMode == PlaybackRepeatMode.all ? 0 : -1);
    if (nextIndex < 0 || nextIndex == _state.currentIndex) return;
    final next = _state.queue[nextIndex];
    if (downloads.contains(next.id) || downloads.isDownloading(next.id)) {
      return;
    }
    unawaited(
      downloads.preload(next).then((ok) {
        if (ok && !_disposed) _setSourceReadiness(next.id, 'ready');
      }, onError: (Object _) {}),
    );
  }

  void setQuality(AudioQuality quality) {
    if (_quality == quality) return;
    _quality = quality;
    _sourceCache.clear();
  }

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
    await _engine.setLoudnessNormalization(_flowSettings.normalizeLoudness);
  }

  Future<void> setQueue(
    List<UnifiedTrack> tracks, {
    int startIndex = 0,
    bool autoplay = false,
  }) async {
    await _dropGapless();
    final safeIndex = tracks.isEmpty
        ? -1
        : startIndex.clamp(0, tracks.length - 1);
    _emit(
      _state.copyWith(
        queue: List.unmodifiable(tracks),
        currentIndex: safeIndex,
        position: Duration.zero,
        duration: Duration.zero,
        sourceReadiness: const {},
        errorMessage: null,
      ),
    );
    await _persist();
    if (autoplay && safeIndex >= 0) {
      await _openCurrent(play: true);
    } else {
      _startNextPreflight();
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

  Future<void> switchSource(TrackSource source) async {
    final track = _state.currentTrack;
    if (track == null ||
        !track.sources.any(
          (candidate) => _sourceKey(candidate) == _sourceKey(source),
        )) {
      throw const PlaybackFailedException(
        'Этот источник не относится к текущему треку.',
      );
    }
    final active = _state.activeTrackSource;
    if (active != null && _sourceKey(active) == _sourceKey(source)) return;

    final previous = _state;
    final position = _state.position;
    _emit(_state.copyWith(buffering: true, errorMessage: null));
    try {
      final resolved = await _resolveSource(source);
      await _engine.open(resolved, play: previous.playing, start: position);
      _lastSuccessfulProvider[track.id] = source.provider;
      _emit(
        _state.copyWith(
          activeTrackSource: source,
          activeAudioSource: resolved,
          buffering: false,
          playing: previous.playing,
          position: position,
          errorMessage: null,
        ),
      );
      _showSourceNotice(
        active == null
            ? 'Источник: ${_providerTitle(source.provider)}'
            : 'Переключено: ${_providerTitle(active.provider)} → ${_providerTitle(source.provider)}',
      );
      _scheduleAccessCheck();
      _startNextPreflight();
    } on Object catch (error) {
      _emit(
        previous.copyWith(
          buffering: false,
          errorMessage:
              'Не удалось переключиться на ${_providerTitle(source.provider)}.',
        ),
      );
      throw PlaybackFailedException(
        'Не удалось переключиться на ${_providerTitle(source.provider)}: $error',
      );
    }
  }

  Future<void> prepareCurrent({Duration start = Duration.zero}) async {
    if (_state.currentTrack == null) return;
    await _openCurrent(play: false, start: start);
  }

  Future<void> play() async {
    if (_state.currentTrack == null) {
      return;
    }
    final provider = _state.activeTrackSource?.provider;
    if (provider != null &&
        _state.activeAudioSource?.streamUrl.isScheme('file') != true) {
      await _authorizeSource?.call(provider);
    }
    if (_state.activeAudioSource == null ||
        _state.activeAudioSource!.isExpired()) {
      await _openCurrent(play: true, start: _state.position);
      return;
    }
    await _engine.play();
  }

  Future<void> pause() => _engine.pause();

  /// Плавно уводит громкость в ноль и ставит паузу; громкость пользователя
  /// возвращается сразу после паузы, чтобы следующее «Play» звучало как раньше.
  ///
  /// Если в этот момент идёт переход Flow, пауза наступит сразу после него —
  /// следующий трек не успеет заиграть. Пропуск трека во время затухания
  /// отменяет его: человек явно не спит.
  @override
  Future<void> fadeOutAndPause({
    Duration duration = const Duration(seconds: 12),
  }) async {
    if (_transitioning) {
      _pauseAfterTransition = true;
      return;
    }
    if (!_state.playing) {
      await pause();
      return;
    }
    final generation = ++_fadeGeneration;
    final targetVolume = _state.volume;
    _fading = true;
    var cancelled = false;
    try {
      const steps = 24;
      final stepDuration = Duration(
        milliseconds: duration.inMilliseconds ~/ steps,
      );
      for (var step = 1; step <= steps; step++) {
        if (_disposed || !_state.playing) break;
        if (generation != _fadeGeneration) {
          cancelled = true;
          break;
        }
        final eased = 1 - pow(1 - step / steps, 2);
        await _engine.setVolume(targetVolume * (1 - eased));
        if (stepDuration > Duration.zero) {
          await Future<void>.delayed(stepDuration);
        }
      }
      if (!cancelled && generation == _fadeGeneration) await _engine.pause();
    } finally {
      if (generation == _fadeGeneration) {
        _fading = false;
        // Громкость, которую человек мог поменять во время затухания, важнее.
        final restore = _volumeDuringFade ?? targetVolume;
        _volumeDuringFade = null;
        await _engine.setVolume(restore);
        _emit(_state.copyWith(volume: restore));
      }
    }
  }

  /// Режим «до конца трека»: Flow не начинает следующий трек заранее, а по
  /// окончании текущего плеер встаёт на паузу.
  @override
  void setStopAfterCurrent(bool value) {
    _stopAfterCurrent = value;
    if (value) unawaited(_dropGapless());
  }

  @override
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
    if (_fading) {
      // Затухание само вернёт эту громкость, когда закончится.
      _volumeDuringFade = safeVolume;
      _emit(_state.copyWith(volume: safeVolume));
      await _persist();
      return;
    }
    _emit(_state.copyWith(volume: safeVolume));
    await _engine.setVolume(safeVolume);
    await _persist();
  }

  Future<void> setShuffle(bool enabled) async {
    await _dropGapless();
    _emit(_state.copyWith(shuffle: enabled));
    await _engine.setShuffle(enabled);
  }

  Future<void> setRepeatMode(PlaybackRepeatMode mode) async {
    await _dropGapless();
    _emit(_state.copyWith(repeatMode: mode));
    await _engine.setRepeatMode(mode);
  }

  Future<void> addToQueue(UnifiedTrack track) async {
    await _dropGapless();
    _emit(_state.copyWith(queue: [..._state.queue, track]));
    await _persist();
    _startNextPreflight();
  }

  Future<void> appendToQueue(Iterable<UnifiedTrack> tracks) async {
    final additions = tracks
        .where((track) => !_state.queue.any((item) => item.id == track.id))
        .toList(growable: false);
    if (additions.isEmpty) return;
    _emit(_state.copyWith(queue: [..._state.queue, ...additions]));
    await _persist();
    _startNextPreflight();
  }

  Future<void> playNext(UnifiedTrack track) async {
    await _dropGapless();
    final insertAt = (_state.currentIndex + 1).clamp(0, _state.queue.length);
    final queue = [..._state.queue]..insert(insertAt, track);
    _emit(_state.copyWith(queue: queue));
    await _persist();
    _startNextPreflight();
  }

  Future<void> skipToIndex(int index) async {
    if (index < 0 ||
        index >= _state.queue.length ||
        index == _state.currentIndex) {
      return;
    }
    await _moveTo(index);
    await _persist();
  }

  Future<void> removeAt(int index) async {
    await _dropGapless();
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
      await _moveTo(nextIndex);
      await _persist();
      return;
    }

    final candidate = _state.currentIndex + 1;
    if (candidate < _state.queue.length) {
      await _moveTo(candidate);
    } else if (_state.repeatMode == PlaybackRepeatMode.all) {
      await _moveTo(0);
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
      await _moveTo(candidate);
    } else if (_state.repeatMode == PlaybackRepeatMode.all) {
      await _moveTo(_state.queue.length - 1);
    } else {
      await seek(Duration.zero);
    }
    await _persist();
  }

  Future<void> _moveTo(int index) async {
    if (_transitioning || index < 0 || index >= _state.queue.length) return;
    if (_fading) {
      // Ручной пропуск во время таймера сна отменяет затухание.
      _fadeGeneration++;
      _fading = false;
      final restore = _volumeDuringFade ?? _state.volume;
      _volumeDuringFade = null;
      await _engine.setVolume(restore);
    }
    final targetVolume = _state.volume;
    final duration = _effectiveTransitionDuration(index);
    if (!_flowSettings.enabled ||
        duration == Duration.zero ||
        !_state.playing) {
      _emit(_state.copyWith(currentIndex: index));
      await _openCurrent(play: true);
      return;
    }
    _transitioning = true;
    try {
      final half = Duration(milliseconds: duration.inMilliseconds ~/ 2);
      await _rampVolume(targetVolume, 0, half);
      if (_disposed) return;
      _emit(_state.copyWith(currentIndex: index));
      await _engine.setVolume(0);
      if (_pauseAfterTransition) {
        // Таймер сна сработал посреди перехода: новый трек не запускаем.
        await _openCurrent(play: false);
      } else {
        await _openCurrent(play: true);
        await _rampVolume(0, targetVolume, half);
      }
    } finally {
      _transitioning = false;
      _pauseAfterTransition = false;
      // Даже если следующий трек не открылся, движок не должен остаться на
      // нулевой громкости: иначе всё дальнейшее играет беззвучно.
      if (!_disposed) {
        await _engine.setVolume(targetVolume);
        _emit(_state.copyWith(volume: targetVolume));
      }
    }
  }

  Duration _effectiveTransitionDuration(int nextIndex) {
    final configured = _flowSettings.transitionDuration;
    if (configured == Duration.zero) return Duration.zero;
    final currentProvider = _state.activeTrackSource?.provider;
    final next = _state.queue[nextIndex];
    if (_flowSettings.smartTransitions &&
        smartTransitionSkipsFade(_state.currentTrack, next)) {
      return Duration.zero;
    }
    final nextProvider =
        next.preferredProvider ??
        (next.sources.isEmpty ? null : next.sources.first.provider);
    final sourceFactor =
        currentProvider == null || nextProvider == currentProvider ? 1.0 : .5;
    final trackFactor =
        _state.duration > Duration.zero &&
            _state.duration < const Duration(seconds: 45)
        ? .5
        : 1.0;
    return Duration(
      milliseconds: (configured.inMilliseconds * sourceFactor * trackFactor)
          .round()
          .clamp(300, 12000)
          .toInt(),
    );
  }

  Future<void> _rampVolume(double from, double to, Duration duration) async {
    if (duration <= Duration.zero) {
      await _engine.setVolume(to);
      return;
    }
    const steps = 8;
    final stepDuration = Duration(
      milliseconds: duration.inMilliseconds ~/ steps,
    );
    for (var step = 1; step <= steps; step++) {
      if (_disposed) return;
      final progress = step / steps;
      final eased = 1 - pow(1 - progress, 3);
      await _engine.setVolume(from + (to - from) * eased);
      if (step < steps && stepDuration > Duration.zero) {
        await Future<void>.delayed(stepDuration);
      }
    }
  }

  void _maybePrefetchNext(Duration position) {
    if (!_state.playing ||
        _state.duration <= Duration.zero ||
        _state.duration - position > const Duration(seconds: 30)) {
      return;
    }
    final nextIndex = _state.currentIndex + 1 < _state.queue.length
        ? _state.currentIndex + 1
        : (_state.repeatMode == PlaybackRepeatMode.all &&
                  _state.queue.isNotEmpty
              ? 0
              : -1);
    if (nextIndex < 0) return;
    final next = _state.queue[nextIndex];
    if (_prefetchingTrackIds.add(next.id)) {
      unawaited(
        _prefetch(next).whenComplete(() {
          _prefetchingTrackIds.remove(next.id);
        }),
      );
    }
  }

  Future<void> _prefetch(UnifiedTrack track) async {
    if (_offlineDownloads?.contains(track.id) == true) {
      _setSourceReadiness(track.id, 'ready');
      return;
    }
    _setSourceReadiness(track.id, 'checking');
    final sources = _sourceSelectionPolicy.orderedSources(
      track,
      lastSuccessfulProvider: _lastSuccessfulProvider[track.id],
    );
    for (final source in sources) {
      if (_sourceCache.get(source) != null) {
        _setSourceReadiness(track.id, 'ready');
        return;
      }
      final resolver = _providers.resolverFor(source.provider);
      if (resolver == null) continue;
      try {
        await _authorizeSource?.call(source.provider);
        final resolved = await resolver.resolve(source, quality: _quality);
        if (!resolved.isExpired()) {
          _sourceCache.put(source, resolved);
          _setSourceReadiness(track.id, 'ready');
          return;
        }
      } on Object {
        // Prefetch is opportunistic; normal resolution still reports failures.
      }
    }
    _setSourceReadiness(track.id, 'unavailable');
  }

  void _startNextPreflight() {
    if (_state.queue.isEmpty) return;
    final nextIndex = _state.currentIndex + 1 < _state.queue.length
        ? _state.currentIndex + 1
        : (_state.currentIndex < 0 ? 0 : -1);
    if (nextIndex < 0) return;
    final next = _state.queue[nextIndex];
    if (_state.sourceReadiness[next.id] == 'ready' ||
        !_prefetchingTrackIds.add(next.id)) {
      return;
    }
    unawaited(
      _prefetch(next).whenComplete(() => _prefetchingTrackIds.remove(next.id)),
    );
  }

  void _setSourceReadiness(String trackId, String value) {
    _emit(
      _state.copyWith(
        sourceReadiness: {..._state.sourceReadiness, trackId: value},
      ),
    );
  }

  void _maybeStartAutomaticFlow(Duration position) {
    if (_transitioning ||
        _fading ||
        _stopAfterCurrent ||
        !_flowSettings.enabled ||
        !_state.playing ||
        _state.buffering ||
        _state.repeatMode == PlaybackRepeatMode.one ||
        _state.duration <= Duration.zero) {
      return;
    }
    final nextIndex = _state.currentIndex + 1 < _state.queue.length
        ? _state.currentIndex + 1
        : (_state.repeatMode == PlaybackRepeatMode.all &&
                  _state.queue.isNotEmpty
              ? 0
              : -1);
    if (nextIndex < 0) return;
    final lead = _effectiveTransitionDuration(nextIndex);
    if (lead > Duration.zero && _state.duration - position <= lead) {
      // С перемешиванием Flow должен идти туда же, куда пошёл бы next().
      unawaited(
        _moveTo(
          _state.shuffle && _state.queue.length > 1
              ? _randomOtherIndex()
              : nextIndex,
        ).then((_) => _persist()),
      );
    }
  }

  int _randomOtherIndex() {
    var index = _state.currentIndex;
    while (index == _state.currentIndex) {
      index = _random.nextInt(_state.queue.length);
    }
    return index;
  }

  /// Убирает из очереди ещё не сыгранные треки, подходящие под [test]
  /// (например, только что заблокированного исполнителя в радио).
  Future<int> removeUpcomingWhere(bool Function(UnifiedTrack) test) async {
    await _dropGapless();
    final current = _state.currentIndex;
    final queue = <UnifiedTrack>[];
    var removed = 0;
    for (var i = 0; i < _state.queue.length; i++) {
      final track = _state.queue[i];
      if (i > current && test(track)) {
        removed++;
      } else {
        queue.add(track);
      }
    }
    if (removed == 0) return 0;
    _emit(_state.copyWith(queue: List.unmodifiable(queue)));
    await _persist();
    _startNextPreflight();
    return removed;
  }

  Future<void> _openCurrent({
    required bool play,
    Duration start = Duration.zero,
    Set<String> excludedSourceKeys = const {},
    String? recoveryReason,
  }) async {
    final track = _state.currentTrack;
    if (track == null) {
      return;
    }
    final local = await _offlineDownloads?.localSource(track);
    if (local != null) {
      final source = _offlineDownloads!.downloadedSource(track.id);
      if (source != null) {
        _emit(_state.copyWith(buffering: true, errorMessage: null));
        try {
          await _activateSource(
            track,
            source,
            local,
            play: play,
            start: start,
            failedProviders: const [],
          );
          return;
        } on Object {
          // A corrupt local file should not block an available online source.
        }
      }
    }
    final sources = _sourceSelectionPolicy
        .orderedSources(
          track,
          lastSuccessfulProvider: _lastSuccessfulProvider[track.id],
        )
        .where((source) => !excludedSourceKeys.contains(_sourceKey(source)))
        .toList(growable: false);
    final failures = <String>[];
    ({TrackSource source, ResolvedAudioSource resolved})? previewFallback;

    _emit(_state.copyWith(buffering: true, errorMessage: null));
    for (final source in sources) {
      final resolver = _providers.resolverFor(source.provider);
      if (resolver == null) {
        failures.add('${source.provider.name}: resolver не подключён');
        continue;
      }
      // A cached URL may have silently expired upstream; give the source one
      // fresh resolve before moving on to the next provider.
      var attempts = _sourceCache.get(source) == null ? 1 : 2;
      while (attempts-- > 0) {
        try {
          final resolved = await _resolveSource(source);
          if (resolved.preview && sources.length > 1) {
            previewFallback ??= (source: source, resolved: resolved);
            break;
          }
          await _activateSource(
            track,
            source,
            resolved,
            play: play,
            start: start,
            failedProviders: failures,
            recoveryReason: recoveryReason,
          );
          return;
        } on Object catch (error) {
          _sourceCache.invalidate(source);
          if (attempts == 0) {
            failures.add('${source.provider.name}: $error');
          }
        }
      }
    }

    if (previewFallback case final fallback?) {
      await _activateSource(
        track,
        fallback.source,
        fallback.resolved,
        play: play,
        start: start,
        failedProviders: failures,
        recoveryReason: recoveryReason,
      );
      return;
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
    if (!completed || _transitioning) {
      return;
    }
    if (_gapless != null) {
      // Плеер сам перейдёт на поставленный следом трек.
      return;
    }
    if (_fading || _stopAfterCurrent) {
      // Таймер сна: трек закончился — останавливаемся, а не идём дальше.
      _stopAfterCurrent = false;
      unawaited(pause());
      return;
    }
    final track = _state.currentTrack;
    final endedEarly =
        _state.activeAudioSource?.preview == true &&
        track?.duration != null &&
        _state.position + const Duration(seconds: 5) < track!.duration! &&
        track.sources.length > 1;
    if (endedEarly) {
      unawaited(_recoverFromEngineError('preview завершён'));
    } else if (_state.repeatMode == PlaybackRepeatMode.one) {
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
      await _openCurrent(
        play: true,
        start: position,
        excludedSourceKeys: active == null ? const {} : {_sourceKey(active)},
        recoveryReason: message,
      );
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

  Future<ResolvedAudioSource> _resolveSource(TrackSource source) async {
    final resolver = _providers.resolverFor(source.provider);
    if (resolver == null) {
      throw StateError('resolver не подключён');
    }
    await _authorizeSource?.call(source.provider);
    var resolved = _sourceCache.get(source);
    resolved ??= await resolver.resolve(source, quality: _quality);
    if (resolved.isExpired()) {
      _sourceCache.invalidate(source);
      resolved = await resolver.resolve(source, quality: _quality);
    }
    _sourceCache.put(source, resolved);
    return resolved;
  }

  Future<void> _activateSource(
    UnifiedTrack track,
    TrackSource source,
    ResolvedAudioSource resolved, {
    required bool play,
    required Duration start,
    required List<String> failedProviders,
    String? recoveryReason,
  }) async {
    final previous = _state.activeTrackSource;
    await _captureLoudness();
    _gapless = null;
    // Автокэш/предзагрузка не должны вытеснить файл, который сейчас звучит.
    _offlineDownloads?.setActiveTrackId(track.id);
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
    if (recoveryReason != null &&
        previous != null &&
        _sourceKey(previous) != _sourceKey(source)) {
      _showSourceNotice(
        '${_providerTitle(previous.provider)} недоступен — продолжили через ${_providerTitle(source.provider)}',
      );
    } else if (failedProviders.isNotEmpty) {
      _showSourceNotice(
        'Выбран доступный источник: ${_providerTitle(source.provider)}',
      );
    }
    await _applyGain(track, resolved);
    _scheduleAccessCheck();
    _startNextPreflight();
    _preloadNextAudio();
  }

  int _sequentialNextIndex() {
    if (_state.queue.isEmpty || _state.currentIndex < 0) return -1;
    if (_state.currentIndex + 1 < _state.queue.length) {
      return _state.currentIndex + 1;
    }
    return _state.repeatMode == PlaybackRepeatMode.all ? 0 : -1;
  }

  /// За ~20 с до конца ставит следующий трек альбома в плеер, чтобы он
  /// начался без паузы (gapless). Работает, только когда кроссфейд не нужен.
  void _maybePrepareGapless(Duration position) {
    if (_gapless != null ||
        _preparingGapless ||
        _transitioning ||
        _fading ||
        !_state.playing ||
        _state.duration <= Duration.zero ||
        _state.duration - position > const Duration(seconds: 20)) {
      return;
    }
    final index = _sequentialNextIndex();
    if (index < 0) return;
    final next = _state.queue[index];
    if (!shouldUseGapless(
      gaplessEnabled: _flowSettings.gapless,
      flowEnabled: _flowSettings.enabled,
      smartTransitions: _flowSettings.smartTransitions,
      transition: _flowSettings.transitionDuration,
      current: _state.currentTrack,
      next: next,
      shuffle: _state.shuffle,
      repeatMode: _state.repeatMode,
      stopAfterCurrent: _stopAfterCurrent,
    )) {
      return;
    }
    _preparingGapless = true;
    unawaited(
      _prepareGapless(
        index,
        next,
      ).whenComplete(() => _preparingGapless = false),
    );
  }

  Future<void> _prepareGapless(int index, UnifiedTrack next) async {
    final currentId = _state.currentTrack?.id;
    ({TrackSource source, ResolvedAudioSource resolved})? prepared;
    final local = await _offlineDownloads?.localSource(next);
    final localSource = _offlineDownloads?.downloadedSource(next.id);
    if (local != null && localSource != null) {
      prepared = (source: localSource, resolved: local);
    } else {
      final sources = _sourceSelectionPolicy.orderedSources(
        next,
        lastSuccessfulProvider: _lastSuccessfulProvider[next.id],
      );
      for (final source in sources) {
        if (_providers.resolverFor(source.provider) == null) continue;
        try {
          final resolved = await _resolveSource(source);
          if (resolved.preview) continue;
          prepared = (source: source, resolved: resolved);
          break;
        } on Object {
          _sourceCache.invalidate(source);
        }
      }
    }
    if (prepared == null ||
        _disposed ||
        _state.currentTrack?.id != currentId ||
        _sequentialNextIndex() != index ||
        _state.queue[index].id != next.id) {
      return;
    }
    await _engine.setQueuedNext(prepared.resolved);
    _gapless = (
      index: index,
      trackId: next.id,
      source: prepared.source,
      resolved: prepared.resolved,
    );
  }

  Future<void> _dropGapless() async {
    if (_gapless == null) return;
    _gapless = null;
    await _engine.setQueuedNext(null);
  }

  /// Плеер сам начал следующий трек: переносим очередь без повторного open.
  Future<void> _onGaplessAdvance() async {
    final prepared = _gapless;
    _gapless = null;
    if (prepared == null || _disposed) return;
    final valid =
        prepared.index < _state.queue.length &&
        _state.queue[prepared.index].id == prepared.trackId;
    if (!valid) {
      // Очередь успела поменяться — открываем то, что действительно следующее.
      await next();
      return;
    }
    final track = _state.queue[prepared.index];
    _offlineDownloads?.setActiveTrackId(track.id);
    _lastSuccessfulProvider[track.id] = prepared.source.provider;
    _emit(
      _state.copyWith(
        currentIndex: prepared.index,
        activeTrackSource: prepared.source,
        activeAudioSource: prepared.resolved,
        position: Duration.zero,
        duration: Duration.zero,
        buffering: false,
        errorMessage: null,
      ),
    );
    await _applyGain(track, prepared.resolved);
    await _persist();
    _scheduleAccessCheck();
    _startNextPreflight();
    _preloadNextAudio();
  }

  void _showSourceNotice(String message) {
    _sourceNoticeTimer?.cancel();
    _emit(_state.copyWith(sourceShiftMessage: message));
    _sourceNoticeTimer = Timer(const Duration(seconds: 6), () {
      _emit(_state.copyWith(sourceShiftMessage: null));
    });
  }

  static String _sourceKey(TrackSource source) =>
      '${source.provider.name}:${source.externalId}';

  static String _providerTitle(MusicProvider provider) => switch (provider) {
    MusicProvider.soundcloud => 'SoundCloud',
    MusicProvider.yandex => 'Яндекс Музыка',
    MusicProvider.youtube => 'YouTube',
    MusicProvider.spotify => 'Spotify',
    MusicProvider.vk => 'VK Музыка',
  };

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
    _offlineDownloads?.setActiveTrackId(null);
    _accessTimer?.cancel();
    _sourceNoticeTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _engine.dispose();
    await _states.close();
  }
}
