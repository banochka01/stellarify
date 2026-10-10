import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/playback/playback_engine.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';

/// Центры полос 10-полосного эквалайзера, Гц (октавные).
const equalizerBands = <int>[
  31,
  62,
  125,
  250,
  500,
  1000,
  2000,
  4000,
  8000,
  16000,
];

/// Предел усиления/ослабления полосы, дБ. Небольшой запас, чтобы громкие
/// мастеринги не клиппировали без отдельного лимитера.
const equalizerMaxGainDb = 9.0;

enum EqualizerPreset {
  flat('flat', 'Ровно', [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  bass('bass', 'Бас', [6, 5, 4, 2, 0, -1, -1, 0, 0, 0]),
  voice('voice', 'Голос', [-3, -2, -1, 1, 3, 4, 4, 2, 0, -1]),
  headphones('headphones', 'Наушники', [3, 2, 0, -1, -1, 0, 1, 2, 3, 2]),
  night('night', 'Ночь', [-4, -3, -1, 0, 1, 1, 0, -1, -3, -5]),
  custom('custom', 'Свой', [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

  const EqualizerPreset(this.id, this.label, this.gains);

  final String id;
  final String label;
  final List<double> gains;

  static EqualizerPreset byId(String? id) => values.firstWhere(
    (preset) => preset.id == id,
    orElse: () => EqualizerPreset.flat,
  );
}

/// Настройка эквалайзера для одного устройства вывода.
final class EqualizerProfile {
  const EqualizerProfile({
    this.enabled = false,
    this.preset = EqualizerPreset.flat,
    this.gains = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  });

  factory EqualizerProfile.fromPreset(EqualizerPreset preset) =>
      EqualizerProfile(enabled: true, preset: preset, gains: preset.gains);

  final bool enabled;
  final EqualizerPreset preset;
  final List<double> gains;

  bool get isNeutral => !enabled || gains.every((gain) => gain.abs() < .05);

  EqualizerProfile copyWith({
    bool? enabled,
    EqualizerPreset? preset,
    List<double>? gains,
  }) => EqualizerProfile(
    enabled: enabled ?? this.enabled,
    preset: preset ?? this.preset,
    gains: gains ?? this.gains,
  );

  EqualizerProfile withBand(int index, double gain) {
    final next = [...gains];
    next[index] = gain.clamp(-equalizerMaxGainDb, equalizerMaxGainDb);
    return EqualizerProfile(
      enabled: true,
      preset: EqualizerPreset.custom,
      gains: next,
    );
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'preset': preset.id,
    'gains': gains,
  };

  static EqualizerProfile fromJson(Object? json) {
    if (json is! Map) return const EqualizerProfile();
    final raw = json['gains'];
    final gains = raw is List
        ? [
            for (var i = 0; i < equalizerBands.length; i++)
              i < raw.length && raw[i] is num
                  ? (raw[i] as num).toDouble().clamp(
                      -equalizerMaxGainDb,
                      equalizerMaxGainDb,
                    )
                  : 0.0,
          ]
        : List<double>.filled(equalizerBands.length, 0);
    return EqualizerProfile(
      enabled: json['enabled'] == true,
      preset: EqualizerPreset.byId(json['preset'] as String?),
      gains: gains,
    );
  }
}

/// Что умеет libmpv конкретной сборки. Сборки media_kit для Windows и
/// Android собраны с `--disable-filters --enable-filter=equalizer`: полосы
/// эквалайзера там работают, а `loudnorm`/`dynaudnorm` — нет.
final class AudioFilterSupport {
  const AudioFilterSupport({
    this.equalizer = false,
    this.loudnorm = false,
    this.dynaudnorm = false,
  });

  static const none = AudioFilterSupport();

  final bool equalizer;
  final bool loudnorm;
  final bool dynaudnorm;

  bool get normalization => loudnorm || dynaudnorm;
}

/// Цепочка для свойства `af` libmpv. Пустая строка — фильтров нет.
String buildAudioFilterChain({
  required AudioFilterSupport support,
  List<double>? equalizerGains,
  bool normalize = false,
}) {
  final filters = <String>[];
  if (support.equalizer && equalizerGains != null) {
    for (
      var i = 0;
      i < equalizerBands.length && i < equalizerGains.length;
      i++
    ) {
      final gain = equalizerGains[i].clamp(
        -equalizerMaxGainDb,
        equalizerMaxGainDb,
      );
      if (gain.abs() < .05) continue;
      filters.add(
        '@eq$i:equalizer=f=${equalizerBands[i]}:t=o:w=1:g=${gain.toStringAsFixed(1)}',
      );
    }
  }
  if (normalize) {
    if (support.loudnorm) {
      filters.add('@norm:loudnorm=I=-16:TP=-1.5:LRA=11');
    } else if (support.dynaudnorm) {
      filters.add('@norm:dynaudnorm=f=250:g=15:p=0.9');
    }
  }
  return filters.join(',');
}

final class AudioEffectsState {
  const AudioEffectsState({
    this.profiles = const {},
    this.deviceId = 'auto',
    this.support,
  });

  /// Профили по id устройства вывода; `auto` — общий профиль по умолчанию.
  final Map<String, EqualizerProfile> profiles;
  final String deviceId;

  /// `null`, пока возможности плеера ещё не проверены.
  final AudioFilterSupport? support;

  EqualizerProfile get current =>
      profiles[deviceId] ?? profiles['auto'] ?? const EqualizerProfile();

  bool get hasOwnProfile => profiles.containsKey(deviceId);

  AudioEffectsState copyWith({
    Map<String, EqualizerProfile>? profiles,
    String? deviceId,
    AudioFilterSupport? support,
  }) => AudioEffectsState(
    profiles: profiles ?? this.profiles,
    deviceId: deviceId ?? this.deviceId,
    support: support ?? this.support,
  );
}

/// Хранит профили эквалайзера по устройствам и применяет нужный при смене
/// устройства вывода.
final class AudioEffectsController extends StateNotifier<AudioEffectsState> {
  AudioEffectsController(this._engine, this._store)
    : super(AudioEffectsState(deviceId: _engine.currentAudioOutput.id)) {
    unawaited(_load());
    _outputSubscription = _engine.audioOutput.listen((device) {
      if (device.id == state.deviceId) return;
      state = state.copyWith(deviceId: device.id);
      unawaited(_apply());
    });
  }

  static const _key = 'resonance.audio.equalizer';

  final PlaybackEngine _engine;
  final SecureKeyValueStore _store;
  late final StreamSubscription<AudioOutputDevice> _outputSubscription;

  Future<void> _load() async {
    final support = await _engine.audioFilterSupport();
    var profiles = const <String, EqualizerProfile>{};
    try {
      final raw = await _store.read(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          profiles = {
            for (final entry in decoded.entries)
              if (entry.key is String)
                entry.key as String: EqualizerProfile.fromJson(entry.value),
          };
        }
      }
    } on Object {
      // Повреждённое значение — начинаем с ровного звука.
    }
    if (!mounted) return;
    state = state.copyWith(profiles: profiles, support: support);
    await _apply();
  }

  /// Меняет профиль текущего устройства (или общий, если [shared]).
  Future<void> update(EqualizerProfile profile, {bool shared = false}) async {
    final key = shared || !state.hasOwnProfile ? 'auto' : state.deviceId;
    state = state.copyWith(profiles: {...state.profiles, key: profile});
    await _apply();
    await _persist();
  }

  /// Отдельная настройка для текущего устройства (наушники, колонки…).
  Future<void> setDeviceSpecific(bool value) async {
    if (state.deviceId == 'auto') return;
    final profiles = {...state.profiles};
    if (value) {
      profiles[state.deviceId] = state.current;
    } else {
      profiles.remove(state.deviceId);
    }
    state = state.copyWith(profiles: profiles);
    await _apply();
    await _persist();
  }

  Future<void> _apply() async {
    final profile = state.current;
    await _engine.setEqualizer(profile.isNeutral ? null : profile.gains);
  }

  Future<void> _persist() async {
    try {
      await _store.write(
        _key,
        jsonEncode({
          for (final entry in state.profiles.entries)
            entry.key: entry.value.toJson(),
        }),
      );
    } on Object {
      // Настройка действует до перезапуска, даже если хранилище недоступно.
    }
  }

  @override
  void dispose() {
    unawaited(_outputSubscription.cancel());
    super.dispose();
  }
}
