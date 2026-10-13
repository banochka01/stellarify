import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/playback/loudness_normalization.dart';
import 'package:resonance/core/playback/stream_quality.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';

final class PlaybackFlowSettings {
  const PlaybackFlowSettings({
    this.enabled = true,
    this.transitionMs = 1600,
    this.normalization = LoudnessNormalizationMode.track,
    this.visualizer = true,
    this.smartTransitions = true,
    this.gapless = true,
    this.qualityMode = StreamQualityMode.auto,
    this.highQualityOnMobile = false,
  });

  final bool enabled;
  final int transitionMs;

  /// Выравнивание громкости: выкл / по треку / по альбому.
  final LoudnessNormalizationMode normalization;
  bool get normalizeLoudness => normalization != LoudnessNormalizationMode.off;

  /// Бесшовный переход: следующий трек альбома заранее ставится в плеер
  /// и начинается без паузы, когда затухание не нужно.
  final bool gapless;

  /// Авто / Высокое / Lossless.
  final StreamQualityMode qualityMode;

  /// Разрешить «Высокое»/«Lossless» выше мобильного потолка в сотовой сети.
  final bool highQualityOnMobile;
  final bool visualizer;

  /// «Умный» переход: не режет концовки live/классики и не вставляет
  /// затухание между соседними треками одного альбома.
  final bool smartTransitions;

  Duration get transitionDuration => Duration(milliseconds: transitionMs);

  PlaybackFlowSettings copyWith({
    bool? enabled,
    int? transitionMs,
    bool? normalizeLoudness,
    LoudnessNormalizationMode? normalization,
    bool? visualizer,
    bool? smartTransitions,
    bool? gapless,
    StreamQualityMode? qualityMode,
    bool? highQualityOnMobile,
  }) => PlaybackFlowSettings(
    enabled: enabled ?? this.enabled,
    transitionMs: transitionMs ?? this.transitionMs,
    normalization:
        normalization ??
        switch (normalizeLoudness) {
          null => this.normalization,
          false => LoudnessNormalizationMode.off,
          true =>
            this.normalization == LoudnessNormalizationMode.off
                ? LoudnessNormalizationMode.track
                : this.normalization,
        },
    visualizer: visualizer ?? this.visualizer,
    smartTransitions: smartTransitions ?? this.smartTransitions,
    gapless: gapless ?? this.gapless,
    qualityMode: qualityMode ?? this.qualityMode,
    highQualityOnMobile: highQualityOnMobile ?? this.highQualityOnMobile,
  );
}

final class PlaybackFlowPreferences {
  PlaybackFlowPreferences(this._store);

  static const _enabledKey = 'resonance.flow.enabled';
  static const _transitionKey = 'resonance.flow.transition_ms';
  static const _normalizeKey = 'resonance.flow.normalize';
  static const _visualizerKey = 'resonance.flow.visualizer';
  static const _smartKey = 'resonance.flow.smart';
  static const _normalizeModeKey = 'resonance.flow.normalize_mode';
  static const _gaplessKey = 'resonance.flow.gapless';
  static const _qualityModeKey = 'resonance.playback.quality_mode';
  static const _highOnMobileKey = 'resonance.playback.high_on_mobile';
  static const allowedTransitionMs = [
    0,
    800,
    1600,
    2500,
    4000,
    6000,
    8000,
    12000,
  ];
  final SecureKeyValueStore _store;

  Future<PlaybackFlowSettings> read() async {
    final values = await Future.wait([
      _store.read(_enabledKey),
      _store.read(_transitionKey),
      _store.read(_normalizeKey),
      _store.read(_visualizerKey),
      _store.read(_smartKey),
      _store.read(_normalizeModeKey),
      _store.read(_gaplessKey),
      _store.read(_qualityModeKey),
      _store.read(_highOnMobileKey),
    ]);
    final parsedTransition = int.tryParse(values[1] ?? '');
    return PlaybackFlowSettings(
      enabled: values[0] != 'false',
      transitionMs: allowedTransitionMs.contains(parsedTransition)
          ? parsedTransition!
          : 1600,
      // Старый флаг «нормализация» без режима означает режим «Трек».
      normalization: values[2] == 'false'
          ? LoudnessNormalizationMode.off
          : LoudnessNormalizationMode.byName(values[5]),
      visualizer: values[3] != 'false',
      smartTransitions: values[4] != 'false',
      gapless: values[6] != 'false',
      qualityMode: StreamQualityMode.byName(values[7]),
      highQualityOnMobile: values[8] == 'true',
    );
  }

  Future<void> write(PlaybackFlowSettings value) => Future.wait([
    _store.write(_enabledKey, value.enabled.toString()),
    _store.write(_transitionKey, value.transitionMs.toString()),
    _store.write(_normalizeKey, value.normalizeLoudness.toString()),
    _store.write(_visualizerKey, value.visualizer.toString()),
    _store.write(_smartKey, value.smartTransitions.toString()),
    _store.write(_normalizeModeKey, value.normalization.name),
    _store.write(_gaplessKey, value.gapless.toString()),
    _store.write(_qualityModeKey, value.qualityMode.name),
    _store.write(_highOnMobileKey, value.highQualityOnMobile.toString()),
  ]);
}

final class PlaybackFlowController extends StateNotifier<PlaybackFlowSettings> {
  PlaybackFlowController(this._preferences)
    : super(const PlaybackFlowSettings()) {
    _load();
  }

  final PlaybackFlowPreferences _preferences;

  Future<void> _load() async {
    try {
      state = await _preferences.read();
    } on Object {
      // Playback remains usable with safe defaults when storage is unavailable.
    }
  }

  Future<PlaybackFlowSettings> update(PlaybackFlowSettings next) async {
    state = next;
    await _preferences.write(next);
    return next;
  }
}
