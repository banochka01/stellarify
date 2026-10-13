import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';

enum CastProtocol {
  chromecast('Chromecast'),
  dlna('DLNA');

  const CastProtocol(this.label);

  final String label;
}

/// Устройство в локальной сети, на которое можно передать звук.
final class CastTarget {
  const CastTarget({
    required this.id,
    required this.name,
    required this.protocol,
  });

  final String id;
  final String name;
  final CastProtocol protocol;

  @override
  bool operator ==(Object other) =>
      other is CastTarget && other.id == id && other.protocol == protocol;

  @override
  int get hashCode => Object.hash(id, protocol);
}

/// Что передаём на устройство: прямой URL потока и подписи.
final class CastMedia {
  const CastMedia({
    required this.url,
    required this.title,
    required this.artist,
    required this.contentType,
    this.artworkUrl,
    this.start = Duration.zero,
  });

  final Uri url;
  final String title;
  final String artist;
  final String contentType;
  final Uri? artworkUrl;
  final Duration start;

  CastMedia at(Duration position) => CastMedia(
    url: url,
    title: title,
    artist: artist,
    contentType: contentType,
    artworkUrl: artworkUrl,
    start: position,
  );
}

/// Причина, по которой трек нельзя передать, или медиа для передачи.
typedef CastableResult = ({CastMedia? media, String? reason});

/// Устройство в сети само скачивает поток по URL, поэтому годится только
/// публичный http(s)-адрес без заголовков авторизации. Локальные файлы и
/// потоки с токеном в заголовках передать нельзя.
CastableResult castableMedia(ResonancePlaybackState state) {
  final track = state.currentTrack;
  final audio = state.activeAudioSource;
  if (track == null || audio == null) {
    return (media: null, reason: 'Сначала включите трек.');
  }
  final url = audio.streamUrl;
  if (!url.isScheme('https') && !url.isScheme('http')) {
    return (
      media: null,
      reason: 'Скачанный трек играет из файла — его нельзя передать по сети.',
    );
  }
  final host = url.host.toLowerCase();
  if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
    return (
      media: null,
      reason: 'Поток идёт через локальный адрес устройства.',
    );
  }
  if (audio.headers.isNotEmpty) {
    return (
      media: null,
      reason:
          'Этот источник требует авторизованных заголовков — устройство не сможет открыть поток.',
    );
  }
  return (
    media: CastMedia(
      url: url,
      title: track.title,
      artist: track.artist,
      contentType: castContentType(audio),
      artworkUrl: _artwork(track),
      start: state.position,
    ),
    reason: null,
  );
}

Uri? _artwork(UnifiedTrack track) {
  final uri = track.artworkUrl;
  return uri != null && uri.isScheme('https') ? uri : null;
}

String castContentType(ResolvedAudioSource audio) {
  if (audio.protocol == StreamProtocol.hls) return 'application/x-mpegURL';
  if (audio.protocol == StreamProtocol.dash) return 'application/dash+xml';
  final codec = audio.codec?.toLowerCase() ?? '';
  final path = audio.streamUrl.path.toLowerCase();
  if (codec.contains('flac') || path.endsWith('.flac')) return 'audio/flac';
  if (codec.contains('opus') ||
      codec.contains('webm') ||
      path.endsWith('.webm')) {
    return 'audio/webm';
  }
  if (codec.contains('aac') || codec.contains('mp4') || path.endsWith('.m4a')) {
    return 'audio/mp4';
  }
  return 'audio/mpeg';
}

/// Активное подключение к устройству.
abstract interface class CastLink {
  Future<void> load(CastMedia media);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// Громкость устройства 0..1.
  Future<void> setVolume(double volume);
  Future<void> close();
}

/// Протокол передачи: обнаружение и подключение.
abstract interface class CastBackend {
  CastProtocol get protocol;

  /// Ищет устройства в течение [timeout]; поток выдаёт текущий список.
  Stream<List<CastTarget>> discover({Duration timeout});
  Future<CastLink> connect(CastTarget target);
}

/// Что плееру нужно от трансляции.
abstract interface class CastPlayback {
  ResonancePlaybackState get state;
  Stream<ResonancePlaybackState> get states;
  Future<void> pause();
}

final class CastState {
  const CastState({
    this.available = false,
    this.discovering = false,
    this.targets = const [],
    this.active,
    this.connecting = false,
    this.playing = false,
    this.volume = .6,
    this.message,
  });

  /// Есть ли на этой платформе хоть один протокол передачи.
  final bool available;
  final bool discovering;
  final List<CastTarget> targets;
  final CastTarget? active;
  final bool connecting;
  final bool playing;
  final double volume;
  final String? message;

  bool get casting => active != null;

  CastState copyWith({
    bool? discovering,
    List<CastTarget>? targets,
    CastTarget? active,
    bool clearActive = false,
    bool? connecting,
    bool? playing,
    double? volume,
    String? message,
    bool clearMessage = false,
  }) => CastState(
    available: available,
    discovering: discovering ?? this.discovering,
    targets: targets ?? this.targets,
    active: clearActive ? null : (active ?? this.active),
    connecting: connecting ?? this.connecting,
    playing: playing ?? this.playing,
    volume: volume ?? this.volume,
    message: clearMessage ? null : (message ?? this.message),
  );
}

final class CastController extends StateNotifier<CastState> {
  CastController(this._backends, this._playback)
    : super(CastState(available: _backends.isNotEmpty));

  final List<CastBackend> _backends;
  final Future<CastPlayback> Function() _playback;
  final _subscriptions = <StreamSubscription<Object?>>[];
  StreamSubscription<ResonancePlaybackState>? _trackWatch;
  CastLink? _link;
  String? _castTrackId;

  Future<void> discover({Duration timeout = const Duration(seconds: 8)}) async {
    if (_backends.isEmpty || state.discovering) return;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    state = state.copyWith(
      discovering: true,
      targets: const [],
      clearMessage: true,
    );
    final found = <CastProtocol, List<CastTarget>>{};
    var pending = _backends.length;
    for (final backend in _backends) {
      _subscriptions.add(
        backend
            .discover(timeout: timeout)
            .listen(
              (targets) {
                found[backend.protocol] = targets;
                if (!mounted) return;
                state = state.copyWith(
                  targets: [for (final list in found.values) ...list],
                );
              },
              onError: (Object _) {},
              onDone: () {
                pending--;
                if (pending == 0 && mounted) {
                  state = state.copyWith(discovering: false);
                }
              },
            ),
      );
    }
  }

  Future<void> connect(CastTarget target) async {
    final backend = _backends
        .where((candidate) => candidate.protocol == target.protocol)
        .firstOrNull;
    if (backend == null) return;
    final playback = await _playback();
    final castable = castableMedia(playback.state);
    final media = castable.media;
    if (media == null) {
      state = state.copyWith(message: castable.reason);
      return;
    }
    await disconnect();
    state = state.copyWith(connecting: true, clearMessage: true);
    try {
      final link = await backend.connect(target);
      await link.load(media);
      _link = link;
      _castTrackId = playback.state.currentTrack?.id;
      await playback.pause();
      state = state.copyWith(active: target, connecting: false, playing: true);
      _trackWatch = playback.states.listen(
        (value) => unawaited(_followTrack(playback, value)),
      );
    } on Object {
      state = state.copyWith(
        connecting: false,
        message: 'Не удалось подключиться к «${target.name}».',
      );
    }
  }

  /// Пользователь переключил трек в приложении — передаём новый.
  Future<void> _followTrack(
    CastPlayback playback,
    ResonancePlaybackState value,
  ) async {
    final link = _link;
    final id = value.currentTrack?.id;
    if (link == null || id == null || id == _castTrackId) return;
    if (value.activeAudioSource == null) return;
    _castTrackId = id;
    final media = castableMedia(value).media;
    if (value.playing) await playback.pause();
    if (media == null) {
      state = state.copyWith(message: castableMedia(value).reason);
      return;
    }
    try {
      await link.load(media.at(Duration.zero));
      state = state.copyWith(playing: true, clearMessage: true);
    } on Object {
      state = state.copyWith(message: 'Устройство не открыло следующий трек.');
    }
  }

  Future<void> togglePlay() async {
    final link = _link;
    if (link == null) return;
    try {
      if (state.playing) {
        await link.pause();
      } else {
        await link.play();
      }
      state = state.copyWith(playing: !state.playing);
    } on Object {
      state = state.copyWith(message: 'Устройство не ответило.');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _link?.seek(position);
    } on Object {
      state = state.copyWith(message: 'Устройство не поддерживает перемотку.');
    }
  }

  Future<void> setVolume(double volume) async {
    final value = volume.clamp(0, 1).toDouble();
    state = state.copyWith(volume: value);
    try {
      await _link?.setVolume(value);
    } on Object {
      // Не все приёмники дают менять громкость.
    }
  }

  Future<void> disconnect() async {
    await _trackWatch?.cancel();
    _trackWatch = null;
    final link = _link;
    _link = null;
    _castTrackId = null;
    if (link != null) {
      try {
        await link.close();
      } on Object {
        // Устройство могло уже пропасть из сети.
      }
    }
    if (mounted) {
      state = state.copyWith(clearActive: true, playing: false);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(disconnect());
    super.dispose();
  }
}
