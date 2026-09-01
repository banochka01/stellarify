import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';
import 'package:uuid/uuid.dart';

final waveControllerProvider = StateNotifierProvider<WaveController, WaveState>(
  (ref) {
    return WaveController(
      ref.watch(resonanceHttpClientProvider).dio,
      BackendEndpoint.requireCurrent,
      ref.watch(secureTokenRepositoryProvider),
      ref.watch(playbackServiceProvider.future),
    );
  },
);

class WaveState {
  const WaveState({
    this.active = false,
    this.loading = false,
    this.sessionId,
    this.error,
    this.discovery = .3,
  });

  final bool active;
  final bool loading;
  final String? sessionId;
  final String? error;
  final double discovery;

  WaveState copyWith({
    bool? active,
    bool? loading,
    String? sessionId,
    String? error,
    bool clearError = false,
    double? discovery,
  }) => WaveState(
    active: active ?? this.active,
    loading: loading ?? this.loading,
    sessionId: sessionId ?? this.sessionId,
    error: clearError ? null : error ?? this.error,
    discovery: discovery ?? this.discovery,
  );
}

class WaveController extends StateNotifier<WaveState> {
  WaveController(this._dio, this._baseUri, this._tokens, this._serviceFuture)
    : super(const WaveState());

  final Dio _dio;
  final Uri Function() _baseUri;
  final SecureTokenRepository _tokens;
  final Future<PlaybackService> _serviceFuture;
  StreamSubscription<ResonancePlaybackState>? _subscription;
  String? _currentTrackId;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  bool _fetching = false;
  final Map<String, _WaveMeta> _metadata = {};

  Future<void> start({
    Iterable<UnifiedTrack> taste = const [],
    double discovery = .3,
  }) async {
    if (state.loading) return;
    state = state.copyWith(
      loading: true,
      discovery: discovery,
      clearError: true,
    );
    try {
      final seeds = <String>{
        for (final track in taste) track.artist.trim(),
      }.where((value) => value.isNotEmpty).take(5).toList(growable: false);
      final response = await _dio.postUri<Map<String, dynamic>>(
        _baseUri().resolve('/api/v1/wave/sessions'),
        data: {
          'seedQueries': seeds,
          'enabledProviders': ['soundcloud', 'yandex'],
          'discovery': discovery,
          'mood': 'all',
          'language': 'any',
        },
        options: await _options(),
      );
      final batch = _parseBatch(response.data);
      final service = await _serviceFuture;
      await service.setQueue(batch.tracks, autoplay: true);
      state = WaveState(
        active: true,
        sessionId: batch.sessionId,
        discovery: discovery,
      );
      await _subscription?.cancel();
      _subscription = service.states.listen(_onPlayback);
      _onPlayback(service.state);
    } on Object catch (error) {
      state = WaveState(error: _message(error), discovery: discovery);
    }
  }

  Future<void> stop() async {
    final id = state.sessionId;
    state = WaveState(discovery: state.discovery);
    await _subscription?.cancel();
    _subscription = null;
    if (id != null) {
      try {
        await _dio.deleteUri<void>(
          _baseUri().resolve('/api/v1/wave/sessions/$id'),
        );
      } on DioException {
        // The local stop is authoritative; an expired server session is harmless.
      }
    }
  }

  void _onPlayback(ResonancePlaybackState playback) {
    if (!state.active) return;
    final track = playback.currentTrack;
    if (_currentTrackId != null && track?.id != _currentTrackId) {
      final ratio = _currentDuration.inMilliseconds <= 0
          ? 0.0
          : _currentPosition.inMilliseconds / _currentDuration.inMilliseconds;
      unawaited(
        _feedback(
          _currentTrackId!,
          ratio >= .85 ? 'finished' : 'skipped',
          _currentPosition,
        ),
      );
    }
    if (track != null && track.id != _currentTrackId) {
      _currentTrackId = track.id;
      _currentPosition = Duration.zero;
      _currentDuration = playback.duration;
      unawaited(_feedback(track.id, 'started', Duration.zero));
    } else {
      _currentPosition = playback.position;
      _currentDuration = playback.duration;
    }
    final remaining = playback.queue.length - playback.currentIndex - 1;
    if (remaining <= 4) unawaited(_next());
  }

  Future<void> _next() async {
    final id = state.sessionId;
    if (id == null || _fetching) return;
    _fetching = true;
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _baseUri().resolve('/api/v1/wave/sessions/$id/next'),
        options: await _options(),
      );
      final batch = _parseBatch(response.data);
      await (await _serviceFuture).appendToQueue(batch.tracks);
    } on Object catch (error) {
      state = state.copyWith(error: _message(error));
    } finally {
      _fetching = false;
    }
  }

  Future<void> _feedback(
    String localTrackId,
    String type,
    Duration played,
  ) async {
    final id = state.sessionId;
    final meta = _metadata[localTrackId];
    if (id == null || meta == null) return;
    try {
      await _dio.postUri<Map<String, dynamic>>(
        _baseUri().resolve('/api/v1/wave/sessions/$id/feedback'),
        data: {
          'eventId': const Uuid().v4(),
          'type': type,
          'trackId': meta.externalId,
          'provider': meta.provider.name,
          if (meta.batchId != null) 'batchId': meta.batchId,
          'playedDurationMs': played.inMilliseconds,
        },
        options: await _options(),
      );
    } on DioException {
      // Feedback must never interrupt playback.
    }
  }

  _WaveBatch _parseBatch(Map<String, dynamic>? json) {
    final sessionId = json?['sessionId'];
    final rawItems = json?['items'];
    if (sessionId is! String || rawItems is! List) {
      throw const FormatException('Invalid wave response');
    }
    final tracks = <UnifiedTrack>[];
    for (final raw in rawItems) {
      final item = Map<String, dynamic>.from(raw as Map);
      final provider = MusicProvider.values.byName(item['provider'] as String);
      final externalId = item['id'] as String;
      final title = item['title'] as String;
      final artist = item['artist'] as String;
      final externalUrl = Uri.parse(item['externalUrl'] as String);
      final artwork = Uri.tryParse(item['artworkUrl'] as String? ?? '');
      final track = UnifiedTrack(
        id: '${provider.name}:$externalId',
        title: title,
        normalizedTitle: title.trim().toLowerCase(),
        artist: artist,
        normalizedArtist: artist.trim().toLowerCase(),
        album: item['album'] as String?,
        duration: item['durationMs'] is num
            ? Duration(milliseconds: (item['durationMs'] as num).toInt())
            : null,
        artworkUrl: artwork?.isScheme('https') == true ? artwork : null,
        preferredProvider: provider,
        sources: [
          TrackSource(
            provider: provider,
            externalId: externalId,
            externalUrl: externalUrl,
          ),
        ],
      );
      tracks.add(track);
      _metadata[track.id] = _WaveMeta(
        provider,
        externalId,
        item['batchId'] as String?,
      );
    }
    if (tracks.isEmpty) throw const FormatException('Empty wave');
    return _WaveBatch(sessionId, tracks);
  }

  Future<Options?> _options() async {
    final headers = <String, String>{};
    for (final provider in MusicProvider.values) {
      final token = await _tokens.read(provider);
      if (token?.isNotEmpty == true) {
        headers['X-${provider.name}-Token'] = token!;
      }
    }
    return headers.isEmpty ? null : Options(headers: headers);
  }

  String _message(Object error) {
    if (error is DioException) {
      return error.response?.statusCode == 401
          ? 'Подключите Яндекс Музыку или проверьте серверные источники.'
          : 'Не удалось продолжить волну. Проверьте подключение.';
    }
    return 'Волна пока не смогла подобрать треки.';
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

class _WaveBatch {
  const _WaveBatch(this.sessionId, this.tracks);
  final String sessionId;
  final List<UnifiedTrack> tracks;
}

class _WaveMeta {
  const _WaveMeta(this.provider, this.externalId, this.batchId);
  final MusicProvider provider;
  final String externalId;
  final String? batchId;
}
