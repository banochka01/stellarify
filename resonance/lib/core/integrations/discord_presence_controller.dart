import 'dart:async';
import 'dart:io';

import 'package:flutter_discord_rpc/flutter_discord_rpc.dart' as discord;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/playback_state.dart';

const bundledDiscordApplicationId = String.fromEnvironment(
  'RESONANCE_DISCORD_APPLICATION_ID',
);

typedef DiscordPresenceGatewayFactory =
    DiscordPresenceGateway Function(String applicationId);

abstract interface class DiscordPlaybackFeed {
  ResonancePlaybackState get state;
  Stream<ResonancePlaybackState> get states;
}

abstract interface class DiscordPresenceGateway {
  Future<void> connect();
  Future<void> update(DiscordPresenceActivity activity);
  Future<void> disconnect();
}

final class DiscordPresenceActivity {
  const DiscordPresenceActivity({
    required this.title,
    required this.artist,
    required this.playing,
    this.artworkUrl,
    this.startedAt,
    this.endsAt,
  });

  factory DiscordPresenceActivity.fromPlayback(
    ResonancePlaybackState playback, {
    DateTime? now,
  }) {
    final track = playback.currentTrack;
    if (track == null) {
      return const DiscordPresenceActivity(
        title: 'Выбирает музыку',
        artist: 'Resonance',
        playing: false,
      );
    }
    final timestamp = now ?? DateTime.now();
    final hasProgress =
        playback.playing &&
        playback.duration > Duration.zero &&
        playback.position < playback.duration;
    final startedAt = hasProgress
        ? timestamp.subtract(playback.position)
        : null;
    final endsAt = hasProgress
        ? timestamp.add(playback.duration - playback.position)
        : null;
    final artwork = track.artworkUrl;
    return DiscordPresenceActivity(
      title: track.title,
      artist: track.artist,
      playing: playback.playing,
      artworkUrl: artwork?.scheme == 'https' ? artwork.toString() : null,
      startedAt: startedAt,
      endsAt: endsAt,
    );
  }

  final String title;
  final String artist;
  final bool playing;
  final String? artworkUrl;
  final DateTime? startedAt;
  final DateTime? endsAt;
}

final class DiscordRpcGateway implements DiscordPresenceGateway {
  DiscordRpcGateway(this._applicationId);

  static String? _initializedApplicationId;
  final String _applicationId;

  @override
  Future<void> connect() async {
    final initialized = _initializedApplicationId;
    if (initialized == null) {
      await discord.FlutterDiscordRPC.initialize(_applicationId);
      _initializedApplicationId = _applicationId;
    } else if (initialized != _applicationId) {
      throw StateError(
        'Discord Application ID changed; restart Resonance to reconnect.',
      );
    }
    await discord.FlutterDiscordRPC.instance.connect().timeout(
      const Duration(seconds: 6),
    );
  }

  @override
  Future<void> update(DiscordPresenceActivity activity) {
    final artwork = activity.artworkUrl;
    return discord.FlutterDiscordRPC.instance.setActivity(
      activity: discord.RPCActivity(
        activityType: discord.ActivityType.listening,
        details: _discordText(activity.title),
        state: _discordText(activity.artist),
        timestamps: activity.playing
            ? discord.RPCTimestamps(
                start: activity.startedAt?.millisecondsSinceEpoch,
                end: activity.endsAt?.millisecondsSinceEpoch,
              )
            : null,
        assets: discord.RPCAssets(
          largeImage: artwork,
          largeText: _discordText('${activity.title} — ${activity.artist}'),
        ),
      ),
    );
  }

  @override
  Future<void> disconnect() =>
      discord.FlutterDiscordRPC.instance.disconnect();
}

String _discordText(String value) {
  final normalized = value.trim();
  if (normalized.length < 2) return '$normalized ';
  return normalized.length <= 128 ? normalized : normalized.substring(0, 128);
}

final class DiscordPresenceState {
  const DiscordPresenceState({
    required this.supported,
    this.applicationId = bundledDiscordApplicationId,
    this.enabled = false,
    this.connecting = false,
    this.connected = false,
    this.error,
  });

  final bool supported;
  final String applicationId;
  final bool enabled;
  final bool connecting;
  final bool connected;
  final String? error;

  bool get configured => applicationId.trim().isNotEmpty;
  bool get bundled => bundledDiscordApplicationId.isNotEmpty;

  DiscordPresenceState copyWith({
    String? applicationId,
    bool? enabled,
    bool? connecting,
    bool? connected,
    String? error,
    bool clearError = false,
  }) => DiscordPresenceState(
    supported: supported,
    applicationId: applicationId ?? this.applicationId,
    enabled: enabled ?? this.enabled,
    connecting: connecting ?? this.connecting,
    connected: connected ?? this.connected,
    error: clearError ? null : error ?? this.error,
  );
}

final class DiscordPresenceController
    extends StateNotifier<DiscordPresenceState> {
  DiscordPresenceController(
    this._store,
    this._playbackFuture,
    this._gatewayFactory, {
    bool? supported,
  }) : super(
         DiscordPresenceState(
           supported:
               supported ??
               (Platform.isWindows || Platform.isMacOS || Platform.isLinux),
         ),
       ) {
    unawaited(_initialize());
  }

  static const _enabledKey = 'resonance.discord_presence.enabled';
  static const _applicationIdKey = 'resonance.discord_presence.application_id';
  static const _retryDelay = Duration(seconds: 20);

  final SecureKeyValueStore _store;
  final Future<DiscordPlaybackFeed> _playbackFuture;
  final DiscordPresenceGatewayFactory _gatewayFactory;

  DiscordPresenceGateway? _gateway;
  StreamSubscription<ResonancePlaybackState>? _playbackSubscription;
  Timer? _retryTimer;
  ResonancePlaybackState _playback = const ResonancePlaybackState();
  String? _publishedTrackId;
  bool? _publishedPlaying;
  Duration? _publishedPosition;
  DateTime? _publishedAt;
  bool _disposed = false;
  bool _operationInProgress = false;

  Future<void> _initialize() async {
    if (!state.supported) return;
    try {
      final values = await Future.wait([
        _store.read(_enabledKey),
        _store.read(_applicationIdKey),
      ]);
      if (_disposed) return;
      final storedId = values[1]?.trim() ?? '';
      state = state.copyWith(
        applicationId: storedId.isEmpty
            ? bundledDiscordApplicationId
            : storedId,
        enabled: values[0] == 'true',
      );

      final playback = await _playbackFuture;
      if (_disposed) return;
      _playback = playback.state;
      _playbackSubscription = playback.states.listen(_onPlayback);
      if (state.enabled && state.configured) await _connect();
    } on Object {
      if (_disposed) return;
      state = state.copyWith(
        connecting: false,
        connected: false,
        error: 'Discord Presence временно недоступен.',
      );
    }
  }

  Future<String?> setApplicationId(String value) async {
    final applicationId = value.trim();
    if (applicationId.isNotEmpty &&
        !RegExp(r'^\d{15,22}$').hasMatch(applicationId)) {
      return 'Application ID должен содержать от 15 до 22 цифр.';
    }
    await _disconnect();
    if (_disposed) return null;
    state = state.copyWith(
      applicationId: applicationId,
      connected: false,
      connecting: false,
      clearError: true,
    );
    if (applicationId.isEmpty) {
      await _store.delete(_applicationIdKey);
      if (state.enabled) {
        state = state.copyWith(enabled: false);
        await _store.write(_enabledKey, 'false');
      }
      return null;
    }
    await _store.write(_applicationIdKey, applicationId);
    if (state.enabled) await _connect();
    return null;
  }

  Future<void> setEnabled(bool enabled) async {
    if (!state.supported || _disposed) return;
    if (enabled && !state.configured) {
      state = state.copyWith(
        enabled: false,
        connecting: false,
        connected: false,
        error: 'Сначала укажите Discord Application ID.',
      );
      return;
    }
    state = state.copyWith(
      enabled: enabled,
      clearError: true,
      connected: enabled ? state.connected : false,
    );
    await _store.write(_enabledKey, enabled.toString());
    if (enabled) {
      await _connect();
    } else {
      await _disconnect();
    }
  }

  Future<void> retry() => _connect();

  void _onPlayback(ResonancePlaybackState playback) {
    _playback = playback;
    if (!state.connected || !_shouldPublish(playback)) return;
    unawaited(_publish(playback));
  }

  bool _shouldPublish(ResonancePlaybackState playback) {
    final now = DateTime.now();
    final trackChanged = playback.currentTrack?.id != _publishedTrackId;
    final playingChanged = playback.playing != _publishedPlaying;
    final previousPosition = _publishedPosition;
    final previousAt = _publishedAt;
    if (trackChanged || playingChanged || previousPosition == null) return true;
    if (previousAt == null) return true;
    final expected = _publishedPlaying == true
        ? previousPosition + now.difference(previousAt)
        : previousPosition;
    return (playback.position - expected).abs() > const Duration(seconds: 5);
  }

  Future<void> _connect() async {
    if (_disposed ||
        !state.enabled ||
        !state.configured ||
        _operationInProgress) {
      return;
    }
    _operationInProgress = true;
    _retryTimer?.cancel();
    state = state.copyWith(
      connecting: true,
      connected: false,
      clearError: true,
    );
    final gateway = _gatewayFactory(state.applicationId);
    try {
      await gateway.connect();
      if (_disposed || !state.enabled) {
        await gateway.disconnect();
        return;
      }
      _gateway = gateway;
      state = state.copyWith(
        connecting: false,
        connected: true,
        clearError: true,
      );
      await _publish(_playback, force: true);
    } on Object {
      await _safeDisconnect(gateway);
      if (_disposed) return;
      state = state.copyWith(
        connecting: false,
        connected: false,
        error:
            'Discord не найден. Запустите приложение — Resonance подключится автоматически.',
      );
      _scheduleRetry();
    } finally {
      _operationInProgress = false;
    }
  }

  Future<void> _publish(
    ResonancePlaybackState playback, {
    bool force = false,
  }) async {
    final gateway = _gateway;
    if (gateway == null || (!force && !_shouldPublish(playback))) return;
    try {
      await gateway.update(DiscordPresenceActivity.fromPlayback(playback));
      _publishedTrackId = playback.currentTrack?.id;
      _publishedPlaying = playback.playing;
      _publishedPosition = playback.position;
      _publishedAt = DateTime.now();
    } on Object {
      await _safeDisconnect(gateway);
      if (_disposed) return;
      _gateway = null;
      state = state.copyWith(
        connecting: false,
        connected: false,
        error: 'Связь с Discord потеряна. Повторяем подключение автоматически.',
      );
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_disposed || !state.enabled) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () => unawaited(_connect()));
  }

  Future<void> _disconnect() async {
    _retryTimer?.cancel();
    final gateway = _gateway;
    _gateway = null;
    _publishedTrackId = null;
    _publishedPlaying = null;
    _publishedPosition = null;
    _publishedAt = null;
    if (gateway != null) await _safeDisconnect(gateway);
  }

  Future<void> _safeDisconnect(DiscordPresenceGateway gateway) async {
    try {
      await gateway.disconnect();
    } on Object {
      // Discord is optional; disconnect failures never affect playback.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    unawaited(_playbackSubscription?.cancel());
    unawaited(_disconnect());
    super.dispose();
  }
}
