import 'dart:async';

import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:resonance/core/playback/audio_effects.dart';
import 'package:resonance/core/playback/loudness_normalization.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';

final class AudioOutputDevice {
  const AudioOutputDevice({required this.id, required this.label});

  static const automatic = AudioOutputDevice(
    id: 'auto',
    label: 'Системное устройство',
  );

  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is AudioOutputDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

abstract interface class PlaybackEngine {
  Stream<bool> get playing;
  Stream<bool> get buffering;
  Stream<bool> get completed;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<double> get volume;
  Stream<String> get errors;
  Stream<AudioOutputDevice> get audioOutput;
  Stream<List<AudioOutputDevice>> get audioOutputs;
  Stream<bool> get videoAvailable;
  AudioOutputDevice get currentAudioOutput;
  List<AudioOutputDevice> get availableAudioOutputs;
  bool get hasVideo;

  Future<void> open(
    ResolvedAudioSource source, {
    bool play = true,
    Duration start = Duration.zero,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setShuffle(bool enabled);
  Future<void> setRepeatMode(PlaybackRepeatMode mode);
  Future<void> setLoudnessNormalization(bool enabled);

  /// Статический гейн выравнивания громкости, дБ; `null` — без гейна.
  /// Применяется поверх громкости пользователя и не меняет её значение.
  Future<void> setReplayGain(double? gainDb);

  /// Интегральная громкость текущего трека по встроенному измерителю
  /// (LUFS), если сборка плеера его поддерживает.
  Future<double?> measuredLoudnessLufs();

  /// Ставит [source] следующим в плейлист плеера для бесшовного перехода;
  /// `null` убирает поставленный ранее. [gainDb] — гейн выравнивания для
  /// этой записи: плеер применит его в момент перехода, без участия сервиса.
  /// Возвращает `false`, если поставить не удалось.
  Future<bool> setQueuedNext(ResolvedAudioSource? source, {double? gainDb});

  /// Плеер сам перешёл на источник, поставленный через [setQueuedNext].
  /// Значение — громкость (LUFS) доигравшего трека по измерителю, если она
  /// достоверна.
  Stream<double?> get advancedToQueued;

  /// Усиление полос эквалайзера в дБ ([equalizerBands]); `null` — выключен.
  Future<void> setEqualizer(List<double>? gainsDb);

  /// Какие аудиофильтры реально есть в этой сборке плеера.
  Future<AudioFilterSupport> audioFilterSupport();
  Future<void> setAudioOutput(AudioOutputDevice device);
  Future<void> dispose();
}

final class MediaKitPlaybackEngine implements PlaybackEngine {
  MediaKitPlaybackEngine({media_kit.Player? player})
    : player = player ?? media_kit.Player() {
    _playlistSubscription = this.player.stream.playlist.listen((playlist) {
      final queued = _queuedIndex;
      if (queued != null && playlist.index == queued) {
        _queuedIndex = null;
        unawaited(_onAdvanced(playlist.index));
      }
    });
  }

  /// Переход на поставленную запись. Гейн следующего трека применяется
  /// первым — до того, как сервис узнает о смене, чтобы громкий трек не
  /// прозвучал с гейном тихого.
  Future<void> _onAdvanced(int index) async {
    _gainFactor = gainDbToVolumeFactor(_queuedGainDb);
    final gainDb = _queuedGainDb;
    _queuedGainDb = null;
    try {
      await _applyVolume();
    } on Object {
      // Громкость вернётся при следующем setVolume.
    }
    // Измеритель общий для бесшовной цепочки: после первого перехода он
    // копит уже несколько треков, поэтому дальше его показаниям не верим
    // до следующего open().
    final lufs = _meterDirty ? null : await measuredLoudnessLufs();
    _meterDirty = true;
    final useDynamic = gainDb == null;
    if (_dynamicNormalize != useDynamic) {
      _dynamicNormalize = useDynamic;
      await _applyFilters();
    }
    // Доигранные записи убираем: плейлист плеера не должен расти, а его
    // порядок не должен смешиваться с очередью приложения.
    try {
      for (var i = 0; i < index; i++) {
        await player.remove(0);
      }
    } on Object {
      // Лишние записи не мешают: open() всё равно заменит плейлист.
    }
    if (!_advanced.isClosed) _advanced.add(lufs);
  }

  final media_kit.Player player;
  late final StreamSubscription<media_kit.Playlist> _playlistSubscription;
  final _advanced = StreamController<double?>.broadcast();
  int? _queuedIndex;
  double? _queuedGainDb;
  bool _meterDirty = false;
  double _engineVolume = -1;
  bool _gaplessConfigured = false;
  double _userVolume = 100;
  double _gainFactor = 1;

  /// Предел громкости libmpv по умолчанию (`volume-max`).
  static const _maxVolume = 130.0;

  @override
  Stream<bool> get playing => player.stream.playing;

  @override
  Stream<bool> get buffering => player.stream.buffering;

  @override
  Stream<bool> get completed => player.stream.completed;

  @override
  Stream<Duration> get position => player.stream.position;

  @override
  Stream<Duration> get duration => player.stream.duration;

  @override
  Stream<double> get volume => player.stream.volume.map((value) {
    // Источник правды — громкость пользователя. Эхо от собственной смены
    // громкости (гейн) игнорируем; иначе это внешняя смена (системные
    // кнопки), и пересчитываем громкость пользователя из неё.
    if ((value - _engineVolume).abs() > .6) {
      _userVolume = (value / _gainFactor).clamp(0, 100).toDouble();
      _engineVolume = value;
    }
    return _userVolume;
  });

  @override
  Stream<double?> get advancedToQueued => _advanced.stream;

  @override
  Stream<String> get errors => player.stream.error;

  @override
  Stream<AudioOutputDevice> get audioOutput =>
      player.stream.audioDevice.map(_mapDevice);

  @override
  Stream<List<AudioOutputDevice>> get audioOutputs =>
      player.stream.audioDevices.map(_mapDevices);

  @override
  Stream<bool> get videoAvailable => player.stream.tracks
      .map((tracks) => tracks.video.any(_isPlayableVideoTrack))
      .distinct();

  @override
  AudioOutputDevice get currentAudioOutput =>
      _mapDevice(player.state.audioDevice);

  @override
  List<AudioOutputDevice> get availableAudioOutputs =>
      _mapDevices(player.state.audioDevices);

  @override
  bool get hasVideo => player.state.tracks.video.any(_isPlayableVideoTrack);

  @override
  Future<void> open(
    ResolvedAudioSource source, {
    bool play = true,
    Duration start = Duration.zero,
  }) {
    final media = media_kit.Media(
      source.streamUrl.toString(),
      httpHeaders: source.headers,
      start: start == Duration.zero ? null : start,
    );
    _queuedIndex = null;
    _queuedGainDb = null;
    return _openFresh(media, play);
  }

  Future<void> _openFresh(media_kit.Media media, bool play) async {
    if (_meterDirty && _normalize) {
      // Новый трек не бесшовный: пересоздаём фильтры, чтобы измеритель
      // считал только его.
      await _applyFilters();
    }
    _meterDirty = false;
    await player.open(media, play: play);
  }

  @override
  Future<bool> setQueuedNext(
    ResolvedAudioSource? source, {
    double? gainDb,
  }) async {
    try {
      final queued = _queuedIndex;
      if (queued != null) {
        _queuedIndex = null;
        _queuedGainDb = null;
        if (queued < player.state.playlist.medias.length) {
          await player.remove(queued);
        }
      }
      if (source == null) return true;
      if (!_gaplessConfigured) {
        final dynamic platform = player.platform;
        await platform.setProperty('gapless-audio', 'weak');
        await platform.setProperty('prefetch-playlist', 'yes');
        _gaplessConfigured = true;
      }
      await player.add(
        media_kit.Media(
          source.streamUrl.toString(),
          httpHeaders: source.headers,
        ),
      );
      _queuedGainDb = gainDb;
      _queuedIndex = player.state.playlist.medias.length - 1;
      return true;
    } on Object {
      // Без бесшовного режима переход просто пойдёт обычным путём.
      _queuedIndex = null;
      _queuedGainDb = null;
      return false;
    }
  }

  @override
  Future<void> setReplayGain(double? gainDb) async {
    _gainFactor = gainDbToVolumeFactor(gainDb);
    await _applyVolume();
    final useDynamic = gainDb == null;
    if (_dynamicNormalize != useDynamic) {
      _dynamicNormalize = useDynamic;
      await _applyFilters();
    }
  }

  Future<void> _applyVolume() {
    _engineVolume = (_userVolume * _gainFactor).clamp(0, _maxVolume).toDouble();
    return player.setVolume(_engineVolume);
  }

  @override
  Future<double?> measuredLoudnessLufs() async {
    try {
      final support = await audioFilterSupport();
      if (!support.ebur128 || !_normalize || _meterDirty) return null;
      final dynamic platform = player.platform;
      final value = await platform.getProperty('af-metadata/meter');
      return parseEbur128Integrated(value);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> setVolume(double volume) {
    _userVolume = volume;
    return _applyVolume();
  }

  @override
  // Очередь тасует сервис; плейлист плеера держит максимум текущий и
  // поставленный следом трек, и его порядок менять нельзя.
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> setRepeatMode(PlaybackRepeatMode mode) {
    final playlistMode = switch (mode) {
      PlaybackRepeatMode.off ||
      PlaybackRepeatMode.all => media_kit.PlaylistMode.none,
      PlaybackRepeatMode.one => media_kit.PlaylistMode.single,
    };
    return player.setPlaylistMode(playlistMode);
  }

  bool _normalize = false;

  /// Динамический фильтр нужен, только пока нет статического гейна.
  bool _dynamicNormalize = true;
  List<double>? _equalizer;
  Future<AudioFilterSupport>? _support;

  @override
  Future<void> setLoudnessNormalization(bool enabled) {
    _normalize = enabled;
    return _applyFilters();
  }

  @override
  Future<void> setEqualizer(List<double>? gainsDb) {
    _equalizer = gainsDb == null ? null : List.unmodifiable(gainsDb);
    return _applyFilters();
  }

  @override
  Future<AudioFilterSupport> audioFilterSupport() =>
      _support ??= _probeFilters();

  /// libmpv отклоняет неизвестный фильтр ещё при разборе `af`, и свойство
  /// остаётся прежним. Поэтому пробуем каждый фильтр по имени и читаем
  /// `af` обратно — так видно, что собрано в конкретную libmpv.
  Future<AudioFilterSupport> _probeFilters() async {
    try {
      final dynamic platform = player.platform;
      Future<bool> probe(String filter) async {
        await platform.setProperty('af', '@probe:$filter');
        final value = await platform.getProperty('af') as String;
        await platform.setProperty('af', '');
        return value.contains(filter);
      }

      return AudioFilterSupport(
        equalizer: await probe('equalizer'),
        loudnorm: await probe('loudnorm'),
        dynaudnorm: await probe('dynaudnorm'),
        ebur128: await probe('ebur128'),
      );
    } on Object {
      return AudioFilterSupport.none;
    }
  }

  Future<void> _applyFilters() async {
    try {
      final support = await audioFilterSupport();
      final dynamic platform = player.platform;
      await platform.setProperty(
        'af',
        buildAudioFilterChain(
          support: support,
          equalizerGains: _equalizer,
          normalize: _normalize && _dynamicNormalize,
          measure: _normalize,
        ),
      );
    } on Object {
      // Some media backends do not expose libmpv audio filters. Flow must fail open.
    }
  }

  @override
  Future<void> setAudioOutput(AudioOutputDevice device) =>
      player.setAudioDevice(media_kit.AudioDevice(device.id, device.label));

  @override
  Future<void> dispose() async {
    await _playlistSubscription.cancel();
    await _advanced.close();
    await player.dispose();
  }

  static AudioOutputDevice _mapDevice(media_kit.AudioDevice device) =>
      AudioOutputDevice(
        id: device.name,
        label: device.name == 'auto' || device.description.trim().isEmpty
            ? (device.name == 'auto'
                  ? AudioOutputDevice.automatic.label
                  : device.name)
            : device.description.trim(),
      );

  static List<AudioOutputDevice> _mapDevices(
    List<media_kit.AudioDevice> devices,
  ) {
    final mapped = <AudioOutputDevice>[
      AudioOutputDevice.automatic,
      ...devices.where((device) => device.name != 'auto').map(_mapDevice),
    ];
    return {
      for (final device in mapped) device.id: device,
    }.values.toList(growable: false);
  }

  static bool _isPlayableVideoTrack(media_kit.VideoTrack track) =>
      track.id != 'auto' && track.id != 'no';
}
