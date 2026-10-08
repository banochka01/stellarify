import 'dart:async';
import 'dart:io';

import 'package:discord_rich_presence/discord_rich_presence.dart' as discord;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

const bundledDiscordApplicationId = String.fromEnvironment(
  'RESONANCE_DISCORD_APPLICATION_ID',
);

/// Значок Resonance для маленькой картинки в карточке Discord.
const discordBadgeUrl = 'https://music.webcordes.ru/favicon-192.png';

/// Discord отклоняет всю активность, если ссылка на картинку длиннее 256.
const _discordMaxAssetUrl = 256;

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
    this.album,
    this.providerLabel,
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
    final provider =
        playback.activeTrackSource?.provider ?? track.preferredProvider;
    return DiscordPresenceActivity(
      title: track.title,
      artist: track.artist,
      album: track.album,
      playing: playback.playing,
      artworkUrl: discordArtworkUrl(track.artworkUrl),
      startedAt: startedAt,
      endsAt: endsAt,
      providerLabel: provider == null ? null : discordProviderLabel(provider),
    );
  }

  final String title;
  final String artist;
  final bool playing;
  final String? artworkUrl;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final String? album;
  final String? providerLabel;
}

/// Ссылка на обложку, которую Discord сможет показать: только https,
/// без шаблонов вроде `%%` у Яндекса и не длиннее лимита Discord.
String? discordArtworkUrl(Uri? artwork) {
  if (artwork == null || !artwork.isScheme('https')) return null;
  final value = highQualityArtworkUrl(artwork, targetSize: 512);
  if (value.contains('%%') ||
      value.contains('%25%25') ||
      value.length > _discordMaxAssetUrl) {
    return null;
  }
  return value;
}

String discordProviderLabel(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => 'Яндекс Музыка',
  MusicProvider.soundcloud => 'SoundCloud',
  MusicProvider.youtube => 'YouTube',
  MusicProvider.spotify => 'Spotify',
  MusicProvider.vk => 'VK Музыка',
};

final class DiscordRpcGateway implements DiscordPresenceGateway {
  DiscordRpcGateway(String applicationId)
    : _client = discord.Client(clientId: applicationId);

  final discord.Client _client;

  @override
  Future<void> connect() => _client.connect();

  @override
  Future<void> update(DiscordPresenceActivity activity) {
    final artwork = activity.artworkUrl;
    final album = activity.album?.trim();
    final source = activity.providerLabel;
    return _client.setActivity(
      discord.Activity(
        name: 'Resonance',
        type: discord.ActivityType.listening,
        details: _discordText(activity.title),
        state: _discordText(
          activity.playing ? activity.artist : 'На паузе · ${activity.artist}',
        ),
        timestamps: activity.playing && activity.startedAt != null
            ? discord.ActivityTimestamps(
                start: activity.startedAt,
                end: activity.endsAt,
              )
            : null,
        assets: discord.ActivityAssets(
          largeImage: artwork ?? discordBadgeUrl,
          largeText: _discordText(
            album != null && album.isNotEmpty && album != activity.title
                ? album
                : '${activity.title} — ${activity.artist}',
          ),
          smallImage: artwork == null ? null : discordBadgeUrl,
          smallText: artwork == null
              ? null
              : _discordText(
                  source == null ? 'Resonance' : 'Resonance · $source',
                ),
        ),
      ),
    );
  }

  @override
  Future<void> disconnect() => _client.disconnect();
}

/// Discord принимает строки длиной 2–128 символов.
String _discordText(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length < 2) return normalized.isEmpty ? '♪♪' : '$normalized ';
  if (normalized.length <= 128) return normalized;
  var cut = 127;
  // Не разрезаем суррогатную пару посередине.
  final unit = normalized.codeUnitAt(cut - 1);
  if (unit >= 0xD800 && unit <= 0xDBFF) cut--;
  return '${normalized.substring(0, cut)}…';
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
  bool _publishedDuration = false;
  Timer? _publishTimer;
  DateTime? _lastUpdateAt;
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

  /// Discord пропускает обновления чаще ~5 раз в 20 секунд, поэтому быстрые
  /// переключения треков склеиваются, а в Discord уходит последний.
  static const _minUpdateGap = Duration(milliseconds: 1500);

  void _onPlayback(ResonancePlaybackState playback) {
    _playback = playback;
    if (!state.connected || !_shouldPublish(playback)) return;
    if (_publishTimer?.isActive ?? false) return;
    final last = _lastUpdateAt;
    final wait = last == null
        ? Duration.zero
        : _minUpdateGap - DateTime.now().difference(last);
    if (wait <= Duration.zero) {
      unawaited(_publish(playback));
      return;
    }
    _publishTimer = Timer(wait, () {
      _publishTimer = null;
      if (!_disposed && state.connected) unawaited(_publish(_playback));
    });
  }

  bool _shouldPublish(ResonancePlaybackState playback) {
    final now = DateTime.now();
    final trackChanged = playback.currentTrack?.id != _publishedTrackId;
    final playingChanged = playback.playing != _publishedPlaying;
    final previousPosition = _publishedPosition;
    final previousAt = _publishedAt;
    if (trackChanged || playingChanged || previousPosition == null) return true;
    final durationKnown = playback.duration > Duration.zero;
    if (durationKnown != _publishedDuration) return true;
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
      _publishedDuration = playback.duration > Duration.zero;
      _publishedAt = DateTime.now();
      _lastUpdateAt = _publishedAt;
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
    _publishTimer?.cancel();
    _publishTimer = null;
    _publishedDuration = false;
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
    _publishTimer?.cancel();
    unawaited(_playbackSubscription?.cancel());
    unawaited(_disconnect());
    super.dispose();
  }
}
