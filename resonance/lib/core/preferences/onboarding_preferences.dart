import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/music_enums.dart';

final class OnboardingSettings {
  const OnboardingSettings({
    this.completed = false,
    this.providers = const {
      MusicProvider.yandex,
      MusicProvider.soundcloud,
      MusicProvider.youtube,
    },
    this.quality = AudioQuality.high,
  });

  final bool completed;
  final Set<MusicProvider> providers;
  final AudioQuality quality;
}

final class OnboardingPreferences {
  OnboardingPreferences(this._store);

  static const _completedKey = 'resonance.onboarding.completed';
  static const _providersKey = 'resonance.onboarding.providers';
  static const _qualityKey = 'resonance.playback.quality';
  static const _audioOutputKey = 'resonance.playback.audio_output';

  final SecureKeyValueStore _store;

  Future<OnboardingSettings> read() async {
    final values = await Future.wait([
      _store.read(_completedKey),
      _store.read(_providersKey),
      _store.read(_qualityKey),
    ]);
    final providers = (values[1] ?? '')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map(
          (value) => MusicProvider.values.where((item) => item.name == value),
        )
        .where((matches) => matches.isNotEmpty)
        .map((matches) => matches.first)
        .toSet();
    final quality = AudioQuality.values.firstWhere(
      (item) => item.name == values[2],
      orElse: () => AudioQuality.high,
    );
    return OnboardingSettings(
      completed: values[0] == 'true',
      providers: providers.isEmpty
          ? const {
              MusicProvider.yandex,
              MusicProvider.soundcloud,
              MusicProvider.youtube,
            }
          : providers,
      quality: quality,
    );
  }

  Future<void> complete({
    required Set<MusicProvider> providers,
    required AudioQuality quality,
  }) async {
    if (providers.isEmpty) {
      throw ArgumentError.value(providers, 'providers', 'Cannot be empty.');
    }
    final orderedProviders = MusicProvider.values
        .where(providers.contains)
        .map((item) => item.name)
        .join(',');
    await Future.wait([
      _store.write(_providersKey, orderedProviders),
      _store.write(_qualityKey, quality.name),
      _store.write(_completedKey, 'true'),
    ]);
  }

  Future<void> reset() => _store.delete(_completedKey);

  Future<void> setQuality(AudioQuality quality) =>
      _store.write(_qualityKey, quality.name);

  Future<String?> readAudioOutputId() => _store.read(_audioOutputKey);

  Future<void> setAudioOutputId(String id) => _store.write(_audioOutputKey, id);
}
