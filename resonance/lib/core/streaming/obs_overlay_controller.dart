import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/core/streaming/obs_now_playing_server.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';

/// Загружает синхронизированные строки для режима OBS «с текстом».
typedef ObsLyricsLoader = Future<List<ObsLyricLine>> Function(UnifiedTrack);

final class ObsOverlayState {
  const ObsOverlayState({
    this.enabled = false,
    this.starting = false,
    this.url,
    this.error,
  });

  final bool enabled;
  final bool starting;
  final Uri? url;
  final String? error;

  bool get supported =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  ObsOverlayState copyWith({
    bool? enabled,
    bool? starting,
    Uri? url,
    String? error,
    bool clearUrl = false,
    bool clearError = false,
  }) => ObsOverlayState(
    enabled: enabled ?? this.enabled,
    starting: starting ?? this.starting,
    url: clearUrl ? null : url ?? this.url,
    error: clearError ? null : error ?? this.error,
  );
}

final class ObsOverlayController extends StateNotifier<ObsOverlayState> {
  ObsOverlayController(
    this._store,
    this._playbackFuture, {
    this._lyrics,
    ObsNowPlayingServer? server,
  }) : _server = server ?? ObsNowPlayingServer(),
       super(const ObsOverlayState()) {
    unawaited(_initialize());
  }

  static const _enabledKey = 'resonance.obs.enabled';
  final SecureKeyValueStore _store;
  final Future<PlaybackService> _playbackFuture;
  final ObsNowPlayingServer _server;
  final ObsLyricsLoader? _lyrics;
  String? _lyricsTrackId;
  StreamSubscription<Object?>? _playbackSubscription;
  bool _disposed = false;

  Future<void> _initialize() async {
    if (!state.supported) return;
    try {
      final playback = await _playbackFuture;
      if (_disposed) return;
      _onPlayback(playback.state);
      _playbackSubscription = playback.states.listen(_onPlayback);
      if (await _store.read(_enabledKey) == 'true') await setEnabled(true);
    } on Object {
      // OBS is optional and must never block the player startup.
    }
  }

  void _onPlayback(ResonancePlaybackState playback) {
    _server.update(playback);
    final track = playback.currentTrack;
    if (track == null || track.id == _lyricsTrackId || !state.enabled) return;
    _lyricsTrackId = track.id;
    final loader = _lyrics;
    if (loader == null) return;
    unawaited(
      loader(track)
          .then((lines) {
            if (!_disposed) _server.updateLyrics(track.id, lines);
          })
          .catchError((Object _) {}),
    );
  }

  Future<void> setEnabled(bool enabled) async {
    if (!state.supported || state.starting || _disposed) return;
    state = state.copyWith(starting: true, clearError: true);
    try {
      if (enabled) {
        final playback = await _playbackFuture;
        if (_disposed) return;
        await _server.start();
        if (_disposed) {
          await _server.stop();
          return;
        }
        state = state.copyWith(
          enabled: true,
          starting: false,
          url: _server.uri,
          clearError: true,
        );
        _lyricsTrackId = null;
        _onPlayback(playback.state);
      } else {
        await _server.stop();
        state = state.copyWith(
          enabled: false,
          starting: false,
          clearUrl: true,
          clearError: true,
        );
      }
      await _store.write(_enabledKey, enabled.toString());
    } on SocketException {
      state = state.copyWith(
        enabled: false,
        starting: false,
        clearUrl: true,
        error:
            'Порты 17654–17663 заняты. Закройте другой OBS-виджет и попробуйте снова.',
      );
    } on Object {
      state = state.copyWith(
        enabled: false,
        starting: false,
        clearUrl: true,
        error: 'Не удалось запустить локальный OBS-виджет.',
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_playbackSubscription?.cancel());
    _server.dispose();
    super.dispose();
  }
}
